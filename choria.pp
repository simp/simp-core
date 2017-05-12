# default.yaml
#   mcollective_choria::config:
#     use_srv_records: false
#     puppetca_port: 8141
#     puppetdb_port: 8139
#     middleware_hosts: puppet.camelot.local:4222
#
#   mcollective::server_config:
#     plugin.choria.ssldir: /var/lib/choria
#     loglevel: info
#
#   mcollective::client_config:
#     plugin.choria.ssldir: ~/.choria
#     loglevel: warn
#     color: 1
#
#   mcollective::site_policies:
#     - action: "allow"
#       callers: "choria=vagrant.mcollective"
#       actions: "*"
#       facts: "*"
#       classes: "*"
#
#   classes:
#     - profiles::choria
#
# server.yaml
#   mcollective::client: true
#
#   classes:
#     - profiles::choria_nats
#
#
# To set up with user certs
#   chmod g+rX,o+rX -R /opt/puppetlabs/puppet/lib/ruby/gems/
#   chmod g+rX,o+rX -R /opt/puppetlabs/puppet/lib/ruby/2.1.0
#
#   mkdir -p ~/.choria/{certs,private_keys,certificate_requests}
#   cp /var/simp/environments/production/FakeCA/output/users/vagrant.mcollective/vagrant.mcollective.pem ~vagrant/.choria/certs/
#   cp /var/simp/environments/production/FakeCA/output/users/vagrant.mcollective/vagrant.mcollective.pem ~vagrant/.choria/private_keys
#   cp /var/simp/environments/production/FakeCA/output/users/vagrant.mcollective/vagrant.mcollective.pem ~vagrant/.choria/certificate_requests
#   cp /etc/pki/simp/x509/cacerts/cacerts.pem ~vagrant/.choria/certs/ca.pem
#   chown -R vagrant.vagrant ~vagrant/.choria/
#
class profiles::choria {
  include 'mcollective'

  iptables::listen::tcp_stateful { 'nats choria':
    dports => [4222,4223,8222]
  }

  pki::copy { 'choria':
    pki   => true,
  }

  file { '/var/lib/choria':
    ensure => directory
  }
  file {
    default:
      ensure  => 'directory',
      require => File['/var/lib/choria/'];
    '/var/lib/choria/certificate_requests':;
    '/var/lib/choria/certs':;
    '/var/lib/choria/private_keys':;
  }
  file {
    default:
      ensure  => file,
      source  => "/etc/pki/simp_apps/choria/x509/private/${trusted['certname']}.pem",
      require => Pki::Copy['choria'],
      notify  => Service['mcollective'];
    "/var/lib/choria/certs/${trusted['certname']}.pem":;
    "/var/lib/choria/certificate_requests/${trusted['certname']}.pem":;
    "/var/lib/choria/private_keys/${trusted['certname']}.pem":;
    '/var/lib/choria/certs/ca.pem':
      source  => '/etc/pki/simp_apps/choria/x509/cacerts/cacerts.pem';
  }
}

class profiles::choria_nats {
  pki::copy { 'nats':
    pki   => true,
    owner => 'nats',
    group => 'nats'
  }
  class { 'nats':
    cert_file    => "/etc/pki/simp_apps/nats/x509/public/${trusted['certname']}.pub",
    key_file     => "/etc/pki/simp_apps/nats/x509/private/${trusted['certname']}.pem",
    ca_file      => '/etc/pki/simp_apps/nats/x509/cacerts/cacerts.pem',
    manage_user  => true,
    manage_group => true,
    user         => 'nats',
    group        => 'nats'
    require      => Pki::Copy['nats']
  }
}
