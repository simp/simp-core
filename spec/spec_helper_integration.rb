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
include Acceptance::Helpers::SystemGemHelper
include Acceptance::Helpers::Utils


unless ENV['BEAKER_provision'] == 'no'
  hosts.each do |host|
    # Temporarily install facter for beaker helpers fact_on() calls executed
    # during server prep. (We don't have puppet's facter, because in this
    # test, puppet hasn't been installed as part of the prep.)
    #
    # WARNING:  Any facter_on() calls outside of an rspec example (it block)
    #           will be executed as part of server prep with this version of
    #           facter.  Only basic facts will be available.
    install_system_factor_gem(host)
  end
end

RSpec.configure do |c|
  # Readable test descriptions
  c.formatter = :documentation
end
