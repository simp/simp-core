# Set the global Exec path to something reasonable
Exec {
  path => [
    '/usr/local/bin',
    '/usr/local/sbin',
    '/usr/bin',
    '/usr/sbin',
    '/bin',
    '/sbin'
  ]
}


# Map SIMP parameters to NIST Special Publication 800-53, Revision 4
$compliance_profile = 'nist_800_53_rev4'

# Place Hiera customizations based on this variable in hieradata/hostgroups/${::hostgroup}.yaml
#
# Example hostgroup delcaration using a regex match on the hostname:
#   if $::fqdn =~ /ws\d+\.<domain>/ {
#     $hostgroup = 'workstations'
#   }
#   else {
#     $hostgroup = 'default'
#   }
#
$hostgroup = 'default'

# Hiera class lookups and inclusions (replaces `hiera_include()`)
$hiera_classes          = lookup('classes',          Array[String], 'unique', [])
$hiera_class_exclusions = lookup('class_exclusions', Array[String], 'unique', [])
$hiera_included_classes = $hiera_classes - $hiera_class_exclusions
include $hiera_included_classes
