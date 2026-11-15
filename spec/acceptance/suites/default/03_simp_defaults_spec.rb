require 'spec_helper_integration'
require 'json'

test_name 'simp:defaults enforcement and idempotence'

master = only_host_with_role(hosts, 'master')
agents = hosts_with_role(hosts, 'agent')

# After `simp bootstrap` and the client bootstrap, every node should get the
# `simp:defaults` Compliance Engine profile from the environment's hiera.yaml
# and scenario data, and another agent run should change nothing.
describe 'simp:defaults enforcement and idempotence' do
  context 'on the puppetserver' do
    it 'enables the compliance_engine::enforcement Hiera backend' do
      hiera_yaml = YAML.safe_load(on(master, 'cat /etc/puppetlabs/code/environments/production/hiera.yaml').stdout)
      backends = hiera_yaml['hierarchy'].map { |level| level['lookup_key'] }.compact
      expect(backends).to include('compliance_engine::enforcement')
    end

    it 'enforces simp:defaults' do
      result = on(master, 'puppet lookup --environment production --render-as json compliance_engine::enforcement')
      expect(JSON.parse(result.stdout)).to include('simp:defaults')
    end
  end

  agents.each do |host|
    context "on #{host}" do
      it 'has a catalog with settings from simp:defaults' do
        certname = on(host, 'puppet config print certname').stdout.strip
        client_datadir = on(host, 'puppet config print client_datadir').stdout.strip
        catalog = JSON.parse(on(host, "cat #{client_datadir}/catalog/#{certname}.json").stdout)
        resources = catalog['resources'].map { |r| "#{r['type']}[#{r['title']}]" }

        # pupmod-simp-ssh 10 only manages sshd through simp:defaults
        expect(resources).to include('Service[sshd]')
        expect(resources).not_to include('Class[Tcpwrappers]')
      end

      it 'makes no changes on another agent run' do
        on(host, 'puppet agent -t --detailed-exitcodes', acceptable_exit_codes: [0])
      end
    end
  end
end
