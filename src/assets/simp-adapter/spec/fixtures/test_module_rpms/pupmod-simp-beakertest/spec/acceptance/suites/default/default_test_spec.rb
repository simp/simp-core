require 'spec_helper_acceptance'

test_name 'nfs basic'

describe 'nfs basic' do

  before(:context) do
    hosts.each do |host|
      interfaces = fact_on(host, 'interfaces').strip.split(',')
      interfaces.delete_if do |x|
        x =~ /^lo/
      end

      interfaces.each do |iface|
        if fact_on(host, "ipaddress_#{iface}").strip.empty?
          on(host, "ifup #{iface}", :accept_all_exit_codes => true)
        end
      end
    end
  end

  servers = hosts_with_role( hosts, 'nfs_server' )
  clients = hosts_with_role( hosts, 'client' )

  ssh_allow = <<-EOM
    if !defined(Iptables::Listen::Tcp_stateful['i_love_testing']) {
      include '::tcpwrappers'
      include '::iptables'

      tcpwrappers::allow { 'sshd':
        pattern => 'ALL'
      }

      iptables::listen::tcp_stateful { 'i_love_testing':
        order        => 8,
        trusted_nets => ['ALL'],
        dports       => 22
      }
    }
  EOM

  let(:manifest) {
    <<-EOM
      include '::nfs'

      #{ssh_allow}
    EOM
  }

  let(:hieradata) {
    <<-EOM
---
simp_options::firewall : true
simp_options::kerberos : false
simp_options::stunnel : false
simp_options::tcpwrappers : true
simp_options::trusted_nets : ['ALL']

# Set us up for a basic server for right now (no Kerberos)

# These two need to be paired in our case since we expect to manage the Kerberos
# infrastructure for our tests.
nfs::secure_nfs : false
nfs::is_server : #IS_SERVER#
    EOM

  }

  context 'setup' do
    hosts.each do |host|
      it 'should work with no errors' do
        hdata = hieradata.dup
        if servers.include?(host)
          hdata.gsub!(/#NFS_SERVER#/m, fact_on(host, 'fqdn'))
          hdata.gsub!(/#IS_SERVER#/m, 'true')
        else
          hdata.gsub!(/#NFS_SERVER#/m, servers.last.to_s)
          hdata.gsub!(/#IS_SERVER#/m, 'false')
        end

        set_hieradata_on(host, hdata)
        apply_manifest_on(host, manifest, :catch_failures => true)
      end

      it 'should be idempotent' do
        apply_manifest_on(host, manifest, :catch_changes => true)
      end
    end
  end

  server_manifest = <<-EOM
    #{ssh_allow}

    include '::nfs'

    file { '/srv/nfs_share':
      ensure => 'directory',
      owner  => 'root',
      group  => 'root',
      mode   => '0644'
    }

    file { '/srv/nfs_share/test_file':
      ensure  => 'file',
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => 'This is a test'
    }

    nfs::server::export { 'nfs4_root':
      clients     => ['*'],
      export_path => '/srv/nfs_share',
      sec         => ['sys']
    }

    File['/srv/nfs_share'] -> Nfs::Server::Export['nfs4_root']
  EOM

  context "as a server" do
    servers.each do |host|
      it 'should export a directory' do
        apply_manifest_on(host, server_manifest)
      end
    end
  end

  context "as a client" do
    clients.each do |host|
      servers.each do |server|
        it "should mount a directory on the #{server} server" do
          server_fqdn = fact_on(server, 'fqdn')

          client_manifest = <<-EOM
            #{ssh_allow}

            nfs::client::mount { '/mnt/#{server}':
              nfs_server  => '#{server_fqdn}',
              remote_path => '/srv/nfs_share',
              autofs      => false
            }
          EOM

          if servers.include?(host)
            client_manifest = client_manifest + "\n" + server_manifest
          end

          host.mkdir_p("/mnt/#{server}")
          apply_manifest_on(host, client_manifest)
          on(host, %(grep -q 'This is a test' /mnt/#{server}/test_file))
          on(host, %{puppet resource mount /mnt/#{server} ensure=absent})
        end

        it "should mount a directory on the #{server} server with autofs" do
          server_fqdn = fact_on(server, 'fqdn')

          autofs_client_manifest = <<-EOM
            #{ssh_allow}

            nfs::client::mount { '/mnt/#{server}':
              nfs_server  => '#{server_fqdn}',
              remote_path => '/srv/nfs_share'
            }
          EOM

          if servers.include?(host)
            autofs_client_manifest = autofs_client_manifest + "\n" + server_manifest
          end

          apply_manifest_on(host, autofs_client_manifest)
          on(host, %{puppet resource service autofs ensure=stopped})
        end
      end
    end
  end
end
