class site::ipa(
) {

  # Open up ports for IPA
  iptables::listen::udp { 'allow_ipa_server_connections':
    dports => [ 53, 88, 123, 464 ]
  }

  iptables::listen::tcp_stateful { 'allow_ipa_server_connections':
    dports => [ 53, 80, 88, 389, 443, 464, 636 ]
  }
}
