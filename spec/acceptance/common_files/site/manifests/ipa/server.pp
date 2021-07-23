class site::ipa::server(
) {

  # IPA server requires IPv6 on at least 1 configured interface or will both
  # fail to install and then fail to operate. Since /etc/hosts has ::1
  # configured, enabling IPv6 on lo is sufficient.

  sysctl { 'net.ipv6.conf.lo.disable_ipv6':
    ensure  => present,
    value   => 0,
    persist => true
  }
}
