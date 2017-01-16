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


# SIMP Scenarios
#
# Set this variable to make use of the different class sets in heiradata/simp:
#   * `simp` - compliant and secure
#   * `simp-lite` - makes use of many of our modules, but doesn't apply
#        any prohibitive security or compliance features
#   * `poss` or any other setting - don't include any classes by default
$simp_scenario = 'poss'

# Map SIMP parameters to NIST Special Publication 800-53, Revision 4
# See hieradata/compliance_profiles/ for more options.
$compliance_profile = 'nist_800_53_rev4'

# Place Hiera customizations based on this variable in hieradata/hostgroups/${::hostgroup}.yaml
#
# Example hostgroup declaration using a regex match on the hostname:
#   if $facts['fqdn'] =~ /ws\d+\.<domain>/ {
#     $hostgroup = 'workstations'
#   }
#   else {
#     $hostgroup = 'default'
#   }
#
$hostgroup = 'default'

# Include the simp_options class to ensure that defaults provided there can be found:
include '::simp_options'

# Add Puppet classes to the `classes` array in hiera to add them to the system.
# For special cases where a class needs to be removed from the classes array, you
# can use the `class_exclusions` array and it will be subtracted.
$hiera_classes          = lookup('classes',          Array[String], 'unique', [])
$hiera_class_exclusions = lookup('class_exclusions', Array[String], 'unique', [])
$hiera_included_classes = $hiera_classes - $hiera_class_exclusions
include $hiera_included_classes
