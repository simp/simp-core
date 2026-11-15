require 'spec_helper_integration'

test_name 'OpenSCAP scan with simp:defaults'

# Baseline for the DISA STIG scan in 90_compliance_enforcement_spec.rb.
# Report-only: see the 'OpenSCAP scan' shared example.
describe 'OpenSCAP scan with simp:defaults' do
  clients = hosts_with_role(hosts, 'agent') - hosts_with_role(hosts, 'master')
  include_examples 'OpenSCAP scan', clients, label: 'simp-defaults'
end
