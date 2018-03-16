require 'beaker-rspec'
require 'tmpdir'
require 'yaml'
require 'simp/beaker_helpers'
require 'beaker/puppet_install_helper'
include Simp::BeakerHelpers

unless ENV['BEAKER_provision'] == 'no'
  run_puppet_install_helper
end

RSpec.configure do |c|
  # ensure that environment OS is ready on each host
  fix_errata_on hosts

  # Readable test descriptions
  c.formatter = :documentation

  # Configure all nodes in nodeset
  c.before :suite do
    begin
      # Install modules and dependencies from spec/fixtures/modules
      copy_fixture_modules_to( hosts )

      # Generate and install PKI certificates on each SUT
      Dir.mktmpdir do |cert_dir|
        run_fake_pki_ca_on( default, hosts, cert_dir )
        hosts.each do |sut|
          copy_pki_to( sut, cert_dir, '/etc/pki/simp-testing' )
          on( sut, 'chown -R root:root /etc/pki/simp-testing')
          on( sut, 'chmod -R ugo=rX /etc/pki/simp-testing')
        end
      end
    rescue StandardError, ScriptError => e
      if ENV['PRY']
        require 'pry'; binding.pry
      else
        raise e
      end
    end
  end
end
