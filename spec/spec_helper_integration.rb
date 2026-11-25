require 'beaker-rspec'
require 'tmpdir'
require 'yaml'
require 'simp/beaker_helpers'
require_relative 'acceptance/helpers'
require_relative 'acceptance/shared_examples'

include Simp::BeakerHelpers
include Acceptance::Helpers::ExpectScriptHelper
include Acceptance::Helpers::IpaHelper
include Acceptance::Helpers::PasswordHelper
include Acceptance::Helpers::PuppetHelper
include Acceptance::Helpers::RepoHelper
include Acceptance::Helpers::Utils


unless ENV['BEAKER_provision'] == 'no'
  # simp config and the SIMP PKI need every host to have a FQDN
  ensure_fqdns(hosts)

  # simp-beaker-helpers' before(:all) hook reads facts with `puppet facts`
  # (beaker_puppet_helpers' fact_on), so the agent must be installed before
  # any example runs
  hosts.each do |host|
    install_puppet_repo(host)
    install_puppet_agent(host)
  end
end

RSpec.configure do |c|
  # Readable test descriptions
  c.formatter = :documentation
end
