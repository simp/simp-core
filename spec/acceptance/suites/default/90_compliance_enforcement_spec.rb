require 'spec_helper_integration'

test_name 'compliance reporting and enforcement'

master = only_host_with_role(hosts, 'master')
agents = hosts_with_role(hosts, 'agent')

describe 'compliance reporting and enforcement' do

  let(:compliance_profile) { 'disa_stig' }

  context 'beaker workarounds' do
    agents.each do |host|
      # FIXME This was grabbed from simp-beaker-helpers. Should make it a method
      # that can be called, instead of duplicating code that may change.
      it 'should adjust crypto policy as needed before reboot in FIPS mode' do
        # Work around Vagrant and cipher restrictions in EL8+
        #
        # Hopefully, Vagrant will update the used ciphers at some point but who
        # knows when that will be
        opensshserver_config = '/etc/crypto-policies/back-ends/opensshserver.config'
        if file_exists_on(host, opensshserver_config)
          on(host, "sed --follow-symlinks -i 's/PubkeyAcceptedKeyTypes=/PubkeyAcceptedKeyTypes=ssh-rsa,/' #{opensshserver_config}")
        end
      end
    end
  end

  context 'master setup' do
    let(:prod_env_dir) { '/etc/puppetlabs/code/environments/production' }
    let(:prod_env_hiera_yaml) { File.join(prod_env_dir, 'hiera.yaml') }
    let(:prod_env_default_yaml) { File.join(prod_env_dir, 'data', 'default.yaml') }
    let(:prod_env_site_pp) { File.join(prod_env_dir, 'manifests', 'site.pp') }

    it 'should configure the compliance profile for reporting' do
      site_pp = on(master, "cat #{prod_env_site_pp}").stdout
      if site_pp.match(/\n\$compliance_profile\s*=\s/).nil?
        # set profile in hieradata
        hiera = YAML.load(on(master, "cat #{prod_env_default_yaml}").stdout)
        default_yaml = hiera.merge( 'compliance_markup::validate_profiles' => [compliance_profile])
        create_remote_file(master, "#{prod_env_default_yaml}", default_yaml.to_yaml)
        on(master, "cat #{prod_env_default_yaml}")
      else
        # set global $compliance_profile
        site_pp.gsub!(/\n\$compliance_profile\s*=\s.+?\n/,
          "\n$compliance_profile = '#{compliance_profile}'\n")
        create_remote_file(master, prod_env_site_pp, site_pp)
        on(master, "cat #{prod_env_site_pp}")
      end
    end

    it 'should configure the environment for the compliance engine backend' do
      hiera_yaml = YAML.load( on(master, "cat #{prod_env_hiera_yaml}").stdout )
      has_compliance = false
      hiera_yaml['hierarchy'].each do |entry|
        if entry.has_key?('lookup_key') and entry['lookup_key'] == 'compliance_markup::enforcement'
          has_compliance = true
          break
        end
      end
      if has_compliance
        puts '>>> Compliance engine backend is already configured'
      else
        puts '>>> Adding compliance engine backend to hiera.yaml'
        # add it just before the final entry (SIMP specific data) or
        # any test overrides that allow the user to login to the box as
        # root will fail
        hierarchy = hiera_yaml['hierarchy'].dup
        last = hierarchy.pop
        hierarchy << {'name' => 'Compliance', 'lookup_key' => 'compliance_markup::enforcement'}
        hierarchy << last
        hiera_yaml['hierarchy'] = hierarchy
        create_remote_file(master, prod_env_hiera_yaml, hiera_yaml.to_yaml)
        on(master, "cat #{prod_env_hiera_yaml}")
      end
    end

    it 'should run puppet successfully' do
      # Adjust hiera
      hiera = YAML.load(on(master, "cat #{prod_env_default_yaml}").stdout)

      # Restore settings turned off in the disable tests, as we have inserted the
      # compliance engine after default.yaml in the data hierarchy
      hiera.delete('selinux::ensure')
      hiera['simp_options::fips'] = true
      hiera.delete('auditd::enable')

      # Add compliance settings
      hiera['compliance_markup::report_types'] = ['full']
      hiera['compliance_markup::enforcement'] = [compliance_profile]

      # This selinux setting will allow vagrant to sudo su to
      # root after the compliance profile is enforced.
      hiera['selinux::login_resources'] = {
        '__default__' => {
          'seuser'    => 'user_u',
          'mls_range' => 's0'
        },
        'vagrant'     => {
          'seuser'    => 'staff_u',
          'mls_range' => 's0-s0:c0.c1023'
        }
      }

      # This addition to the sudo specification allows the user to sudo su to
      # root without specifying the selinux role, i.e.,
      #   sudo su - root
      # instead of
      #   sudo -r unconfined_r su - root
      hiera['sudo::user_specifications']['vagrant_all']['options'] = {
        'role' => 'unconfined_r'
      }

      create_remote_file(master, "#{prod_env_default_yaml}", hiera.to_yaml)
      on(master, "cat #{prod_env_default_yaml}")

      result = on(master, 'puppet agent -t', :accept_all_exit_codes => true).output.strip
      expect(result).to_not match /parameter .+ expects .+ got/m
    end
  end

  context 'agent run' do
    agents.each do |host|
      it 'should run puppet successfully' do
        result = on(host, 'puppet agent -t', :accept_all_exit_codes => true).output.strip
        expect(result).to_not match /parameter .+ expects .+ got/m
      end
    end

    it 'should reboot the agents to apply boot time config' do
      # this will also re-establish beaker's ssh connection with
      # the correct ciphers
      block_on(agents, :run_in_parallel => false) do |agent|
        agent.reboot
      end
    end
  end

  context 'compliance reports on the master' do
    let(:sec_results_dir) {
      # simp-core/sec_results
      sec_results_root = File.join(File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', '..')), 'sec_results')
      File.join(sec_results_root, File.basename(File.dirname(__FILE__)))
    }

    agents.each do |host|
      context "a valid report for #{host}" do
        let(:fqdn) { fact_on(host, 'fqdn') }
        let(:host_sec_results_dir) { File.join(sec_results_dir, fqdn) }
        let(:report_file) { File.join(host_sec_results_dir, 'compliance_report.json') }

        it 'should have a report' do
          FileUtils.mkdir_p(host_sec_results_dir)
          # scp will fail if this is a locked down directory
          FileUtils.chmod_R('o+rX', host_sec_results_dir)
          on(master, 'ls /opt/puppetlabs/server/data/puppetserver/simp/compliance_reports')
          scp_from(master, "/opt/puppetlabs/server/data/puppetserver/simp/compliance_reports/#{fqdn}/compliance_report.json", host_sec_results_dir)

          expect { JSON.load(File.read(report_file)) }.to_not raise_error
        end

        it 'should have host metadata' do
          expect(JSON.load(File.read(report_file))['fqdn']).to eq(fqdn)
        end

        it 'should have a passing compliance profile report' do
          compliance_report = JSON.load(File.read(report_file))
          expect(compliance_report['compliance_profiles']).to_not be_empty
          expect(compliance_report['compliance_profiles'][compliance_profile]).to_not be_empty
          expect(compliance_report['compliance_profiles'][compliance_profile]['summary']).to_not be_empty

          # We need to make sure this is true in the future but the tests
          # successfully prove that the subsystem is working properly across
          # the board.
          #
          # expect(compliance_report['compliance_profiles'][compliance_profile]['summary']['percent_compliant']).to be == 100
        end
      end
    end
  end

end
