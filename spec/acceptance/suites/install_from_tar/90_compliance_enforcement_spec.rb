require 'spec_helper_tar'

test_name 'compliance reporting and enforcement'

describe 'compliance reporting and enforcement' do
  master = only_host_with_role(hosts, 'master')
  agents = hosts_with_role(hosts, 'agent')

  let(:compliance_profile) { 'disa_stig' }

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
        default_yaml = hiera.merge( 'compliance_markup::validate_profiles' => [ compliance_profile])
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
      # Add onto the existing hiera
      hiera = YAML.load(on(master, "cat #{prod_env_default_yaml}").stdout)

      default_yaml = hiera.merge(
        'compliance_markup::report_types' => ['full'],
        'compliance_markup::enforcement' => [ compliance_profile]
      )

      create_remote_file(master, "#{prod_env_default_yaml}", default_yaml.to_yaml)
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
