require 'beaker-rspec'
require 'tmpdir'
require 'yaml'
require 'simp/beaker_helpers'
include Simp::BeakerHelpers

module Simp
  module TestHelpers
    # Wait specified seconds, logging (bold blue) the remaining seconds to wait
    def self.wait(time_seconds)
      max_width = time_seconds.to_s.size
      while time_seconds > 0
        line = sprintf("\e[1;34m>>>>> Waiting %1$*2$d seconds ...\e[0m", time_seconds, max_width)
        print line
        sleep 1
        print "\b"*line.size
        time_seconds -= 1
      end
      line = sprintf("\e[1;34m>>>>> Waiting %1$*2$d seconds ... Done\e[0m", 0, max_width)
      puts line
    end
  end
end

unless ENV['BEAKER_provision'] == 'no'
  hosts.each do |host|
    # Install Puppet
    if host.is_pe?
      install_pe
    else
      install_puppet
    end
  end
end


RSpec.configure do |c|
  # ensure that environment OS is ready on each host
  fix_errata_on hosts

  # Readable test descriptions
  c.formatter = :documentation

  # Configure all nodes in nodeset
  c.before :suite do
    begin
      # # Install modules and dependencies from spec/fixtures/modules
      # copy_fixture_modules_to( hosts )

      # Generate and install PKI certificates on each SUT
      Dir.mktmpdir do |cert_dir|
        run_fake_pki_ca_on(default, hosts, cert_dir )
        hosts.each{ |sut| copy_pki_to(sut, cert_dir, '/etc/pki/simp-testing' )}
      end

      # add PKI keys
      copy_keydist_to(default)
    rescue StandardError, ScriptError => e
      if ENV['PRY']
        require 'pry'; binding.pry
      else
        raise e
      end
    end
  end
end
