require 'spec_helper_integration'
require 'json'

test_name 'DISA STIG enforcement with the Compliance Engine'

master = only_host_with_role(hosts, 'master')
agents = hosts_with_role(hosts, 'agent')
clients = agents - [master]

# Enforces a Sicura DISA STIG profile together with simp:defaults on every
# node, the way a site would add it:
#
# 1. Add sicura-simp_enterprise_el_disa (the profile data) and
#    sicura-simp_enterprise_el (the classes and defines that data drives)
#    to the production environment's Puppetfile and deploy it with r10k. r10k does no dependency
#    resolution, so the modules' metadata.json caps (OpenVox, pupmod, simp,
#    simp_openldap, ...) are not applied; Puppet itself ignores them.
# 2. Set compliance_engine::enforcement to [<profile>, 'simp:defaults'].
#    The first-listed profile wins for scalar values, so the DISA profile
#    must come first.
# 3. Run Puppet and reboot, then scan the clients with OpenSCAP (report-only).
#
# Environment variables:
#   BEAKER_compliance_profile  - profile to enforce (default disa:mac-1:classified)
#   BEAKER_sicura_disa_ref     - git ref of sicura-simp_enterprise_el_disa
#   BEAKER_sicura_el_ref       - git ref of sicura-simp_enterprise_el
describe 'DISA STIG enforcement with the Compliance Engine' do
  compliance_profile = ENV.fetch('BEAKER_compliance_profile', 'disa:mac-1:classified')

  let(:prod_env_dir) { '/etc/puppetlabs/code/environments/production' }
  let(:prod_env_default_yaml) { File.join(prod_env_dir, 'data', 'default.yaml') }
  let(:r10k) { '/opt/puppetlabs/puppet/bin/r10k' }

  let(:sicura_puppetfile) do
    <<~PUPPETFILE
      mod 'sicura-simp_enterprise_el_disa',
        :git => 'https://github.com/sicuraus/sicura-simp_enterprise_el_disa',
        :ref => '#{ENV.fetch('BEAKER_sicura_disa_ref', '3.2.1')}'

      mod 'sicura-simp_enterprise_el',
        :git => 'https://github.com/sicuraus/sicura-simp_enterprise_el',
        :ref => '#{ENV.fetch('BEAKER_sicura_el_ref', '3.0.5')}'
    PUPPETFILE
  end

  context 'puppetserver setup' do
    it 'adds the Sicura DISA STIG modules to the production Puppetfile' do
      puppetfile = on(master, "cat #{prod_env_dir}/Puppetfile").stdout
      create_remote_file(master, "#{prod_env_dir}/Puppetfile", "#{puppetfile}\n#{sicura_puppetfile}") unless puppetfile.include?('sicura-simp_enterprise_el_disa')

      # retry to work around intermittent connectivity issues
      retry_on(master,
        "cd #{prod_env_dir}; #{r10k} puppetfile install -v info",
        desired_exit_codes: [0],
        retry_interval: 15,
        max_retries: 3,
        verbose: true.to_s)
      on(master, 'simp environment fix production --no-secondary-env --no-writable-env')
      on(master, "test -d #{prod_env_dir}/modules/simp_enterprise_el_disa/SIMP && test -d #{prod_env_dir}/modules/simp_enterprise_el/manifests")
    end

    if ENV.fetch('BEAKER_sicura_el_as_redhat', 'yes') == 'yes'
      # The DISA RHEL benchmarks are confined to os.name RedHat (and the
      # Oracle Linux ones to OracleLinux), so on the AlmaLinux test boxes
      # the profile would enforce almost nothing. Treat the RHEL rebuilds
      # as RHEL, as their STIG content in SCAP Security Guide does.
      it 'applies the RHEL benchmarks to RHEL rebuilds' do
        sed_expr = 's/"os.name":\["RedHat"\]/"os.name":["RedHat","AlmaLinux","Rocky","CentOS"]/g'
        on(master, "find #{prod_env_dir}/modules/simp_enterprise_el_disa/SIMP -name '*.json' -print0 | xargs -0 sed -i '#{sed_expr}'")
        on(master, "grep -rqF '\"os.name\":[\"RedHat\",\"AlmaLinux\"' #{prod_env_dir}/modules/simp_enterprise_el_disa/SIMP")
      end
    end

    it "enforces #{compliance_profile} before simp:defaults" do
      hiera = YAML.safe_load(on(master, "cat #{prod_env_default_yaml}").stdout) || {}

      hiera['compliance_engine::enforcement'] = [compliance_profile, 'simp:defaults']

      # The profile's README lists settings a site must supply, such as the
      # GRUB superuser and password; `simp config` only sets them for the
      # server (as simp_grub::admin root).
      hiera['simp_grub::admin'] = 'root'
      hiera['simp_grub::password'] = encrypt_grub_password(master, test_password(:grub))

      # The STIG profiles turn on repo_gpgcheck, which breaks repos that
      # don't sign their metadata; the profile's README recommends this.
      hiera['yum::config_options'] = { 'repo_gpgcheck' => false }

      set_default_yaml(master, hiera)
      on(master, 'simp environment fix production --no-secondary-env --no-writable-env')
    end

    it 'resolves the enforcement list on the puppetserver' do
      result = on(master, 'puppet lookup --compile --environment production --render-as json compliance_engine::enforcement')
      expect(JSON.parse(result.stdout)).to eq([compliance_profile, 'simp:defaults'])
    end
  end

  context 'puppet runs' do
    # Exit codes 0 and 2 (changes) are fine; 1, 4 and 6 mean failures.
    hosts.each do |host|
      it "applies the profile on #{host}" do
        ensure_ssh_connection(host)
        result = on(host, 'puppet agent -t --detailed-exitcodes', acceptable_exit_codes: [0, 1, 2, 4, 6])
        expect(result.output).not_to match(%r{parameter .+ expects .+ got}m)
        expect(result.output).not_to match(%r{Could not retrieve catalog})

        # Some resources depend on others applied in the same run
        on(host, 'puppet agent -t --detailed-exitcodes', acceptable_exit_codes: [0, 2])
      end
    end

    it 'reboots the clients to apply boot-time settings (FIPS, kernel parameters)' do
      clients.each(&:reboot)
    end

    clients.each do |host|
      it "has no failures after the reboot on #{host}" do
        munge_ssh_crypto_policies(host)
        ensure_ssh_connection(host)
        retry_on(host, 'puppet agent -t --detailed-exitcodes',
          desired_exit_codes: [0, 2],
          retry_interval: 15,
          max_retries: 3,
          verbose: true.to_s)
      end

      it "reports the profile in the catalog of #{host}" do
        certname = on(host, 'puppet config print certname').stdout.strip
        client_datadir = on(host, 'puppet config print client_datadir').stdout.strip
        catalog = JSON.parse(on(host, "cat #{client_datadir}/catalog/#{certname}.json").stdout)
        classes = catalog['resources'].select { |r| r['type'] == 'Class' }.map { |r| r['title'] }
        expect(classes).to include('Simp_enterprise_el')
      end
    end
  end

  context 'OpenSCAP' do
    include_examples 'OpenSCAP scan', clients, label: compliance_profile.tr(':', '_')
  end
end
