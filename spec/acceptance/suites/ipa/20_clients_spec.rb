require 'spec_helper_integration'

def skip_fips(host)
  if fips_enabled(host) && host.host_hash[:roles].include?('no_fips')
    return true
  else
    return false
  end
end

def run_ipa_cmd(host, pass, cmd)
  on(host, "echo \"#{pass}\" | kinit admin")
  result = on(host, cmd)
  on(host, 'kdestroy')

  result
end

describe 'sets up IPA clients' do

  ipa_server  = hosts_with_role(hosts, 'ipa_server').first
  ipa_clients = hosts_with_role(hosts, 'ipa_client')
  domain      = fact_on(master, 'domain')

  admin_password = '@dm1n=P@ssw0r'
  enroll_pass    = 'enrollmentpassword'
  ipa_domain     = domain
  ipa_realm      = ipa_domain.upcase
  ipa_fqdn       = fact_on(ipa_server, 'fqdn')

  context 'classify nodes' do
    it 'modify the existing hieradata' do
      site_pp = <<-EOF
        # All nodes
        node default {
          include 'simp_options'
          include 'simp'
          include 'simp::ipa::install'
        }
        # The puppetserver
        node /puppet/ {
          include 'simp_options'
          include 'simp'
          include 'simp::server'
          include 'pupmod'
          include 'pupmod::master'
          include 'simp::ipa::install'
        }
      EOF
      create_remote_file(master, '/etc/puppetlabs/code/environments/production/manifests/site.pp', site_pp)

      hiera = YAML.load(on(master, 'cat /etc/puppetlabs/code/environments/production/hieradata/default.yaml').stdout)
      default_yaml = hiera.merge(
        'simp::ipa::install::ensure'   => 'present',
        'simp::ipa::install::password' => enroll_pass,
        'simp::ipa::install::server'   => ipa_fqdn,
        'simp::ipa::install::domain'   => ipa_domain,
        'simp::ipa::install::realm'    => ipa_realm
      ).to_yaml
      create_remote_file(master, '/etc/puppetlabs/code/environments/production/hieradata/default.yaml', default_yaml)
    end
  end

  context 'add hosts to ipa server' do
    ipa_clients.each do |client|
      it "should run host-add for #{client}" do
        client_ip = fact_on(client,'ipaddress_eth1')
        cmd = [
          'ipa -v host-add',
          "#{client}.#{ipa_domain}",
          "--ip-address=#{client_ip}",
          '--no-reverse',
          "--password=#{enroll_pass}"
        ].join(' ')

        run_ipa_cmd(ipa_server, admin_password, cmd)
      end
    end
  end

  context 'client prep' do
    ipa_clients.each do |client|
      next if skip_fips(client)

      # it 'should be running haveged for entropy' do
      #   # IPA requires entropy, so use haveged service
      #   on(client, 'puppet resource package haveged ensure=present')
      #   on(client, 'puppet resource service haveged ensure=running enable=true')
      # end
      # it 'should install ipa client tools' do
      #   # Install the IPA client on all hosts
      #   on(client, 'puppet resource package ipa-client ensure=present')
      #   # Admintools for EL6
      #   on(client, 'puppet resource package ipa-admintools ensure=present', accept_all_exit_codes: true)
      # end
      # it 'should set up dnsmasq for now' do
      #   on(client, 'puppet resource package dnsmasq ensure=present')
      #   on(client, 'puppet resource service dnsmasq ensure=running enable=true')
      # end
      it 'should make sure the hostname is fully qualified' do
        fqdn = "#{client}.#{domain}"
        # Ensure that the hostname is set to the FQDN
        on(client, "hostname #{fqdn}")
        create_remote_file(client, '/etc/hostname', fqdn)
        create_remote_file(client, '/etc/sysconfig/network', <<-EOF.gsub(/^\s+/,'')
            NETWORKING=yes
            HOSTNAME=#{fqdn}
            PEERDNS=no
          EOF
        )
        client.reboot
        retry_on(client, 'uptime', :retry_interval => 15 )
      end
    end

    #   it 'should register with the IPA server' do
    #     fqdn = "#{client}.#{ipa_domain}"
    #     ipa_command = [
    #       'ipa-client-install --unattended', # Unattended installation
    #       "--domain=#{ipa_domain}",          # IPA directory domain
    #       "--server=#{ipa_fqdn}",            # IPA server to use
    #       '--enable-dns-updates',            # DNS settings
    #       "--hostname=#{fqdn}",              # Set hostname
    #       '--fixed-primary',                 # Only point at this server and don't use SRV
    #       "--realm=#{ipa_realm}",            # IPA krb5 realm
    #       '--principal=admin',               # Krb5 principal name to use
    #       "--password='#{admin_password}'",  # Admin password
    #       '--noac'                           # Don't update using authconfig
    #     ].join(' ')
    #
    #     on(client, ipa_command)
    #   end
    #   # it 'should rename the FakeCA certs' do
    #   #   on(client, "cp /etc/pki/simp-testing/pki/private/* /etc/pki/simp-testing/pki/private/#{client}.#{ipa_domain}.pem")
    #   #   on(client, "cp /etc/pki/simp-testing/pki/public/* /etc/pki/simp-testing/pki/public/#{client}.#{ipa_domain}.pub")
    #   # end
    # end

    context 'run puppet' do
      agents.each do |agent|
        it "should run the agent on #{agent}" do
          retry_on(agent, 'puppet agent -t',
            :desired_exit_codes => [0],
            :retry_interval     => 15,
            :max_retries        => 5,
            :verbose            => true
          )
        end
      end
    end
  end
end
