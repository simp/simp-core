
require 'spec_helper_integration'

test_name 'Verify Clients booted with simp-lite Scenario'

# facts gathered here are executed when the file first loads and
# use the facter gem temporarily installed into system ruby
puppetserver  = only_host_with_role(hosts, 'master')
agents        = hosts_with_role(hosts, 'agent')
domain        = fact_on(puppetserver, 'domain')
justagents    = agents - [ puppetserver ]

describe 'Verify clients are using simp-lite scenario' do

  context 'check for fips' do
    justagents.each do |agent|
      it 'should not be set to fips' do
        result = on(agent, 'facter fips_enabled')
        expect( result.stdout.strip ).to eq "false"

        on(agent, 'grep "fips=1" /proc/cmdline', :acceptable_exit_codes => [1])
      end
    end
  end

  context 'check for firewall' do
    justagents.each do |agent|
      it 'should not be running' do
        firewalld_state = YAML.load(on(agent, 'puppet resource service firewalld --to_yaml').stdout.strip).dig('service','firewalld','ensure')
        iptables_state = YAML.load(on(agent, 'puppet resource service iptables --to_yaml').stdout.strip).dig('service','firewalld','ensure')
        expect( firewalld_state ).to_not eq "running"
        expect( iptables_state ).to_not eq "running"
      end
    end
    it 'should be running running on puppetserver' do
      firewalld_state = YAML.load(on(puppetserver, 'puppet resource service firewalld --to_yaml').stdout.strip).dig('service','firewalld','ensure')
      iptables_state = YAML.load(on(puppetserver, 'puppet resource service iptables --to_yaml').stdout.strip).dig('service','firewalld','ensure')
      expect("#{firewalld_state}#{iptables_state}").to match(/running/)
    end
  end

  context 'ensure svckill is not running on clients' do
    hosts.each do |host|
      it "should not attempt to kill dnsmasq unless on puppetserver current host: #{host.name}" do
        on(host, 'puppet resource package dnsmasq ensure=installed')
        on(host, 'puppet resource service dnsmasq ensure=running')
        result = on(host, 'puppet agent -t')
        if host == master
          expect(result.stderr).to include("svckill: dnsmasq")
          expect(result.stderr).to include("Warning: svckill: Would have killed:")
        else
          expect(result.stderr).to_not include("Warning: svckill: Would have killed:")
          expect(result.stderr).to_not include("svckill: dnsmasq")
        end
      end
    end
  end

end
