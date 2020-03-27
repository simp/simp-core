module Acceptance
  module Helpers
    module SystemGemHelper

      def install_system_factor_gem(host)
        host.install_package('rubygems')
        # Facter 4.0 needs ruby 2.3 or later and system ruby on EL7
        # is version 2.0.0
        on(host, '/usr/bin/gem install facter --version "<4.0.0"')

        # beaker-helper fact_on() now uses '--json' on facter calls, so
        # we need to make sure the json gem is installed
        result = on(host, 'facter --json fqdn', :accept_all_exit_codes => true)
        if result.exit_code != 0
          # We have old system Ruby (1.8.7) which does not include json.  So,
          # install the pure-Ruby version of json.
          on(host, "gem install json_pure --version '<2.0.0'")
        end
      end

      def uninstall_system_factor_gem(host)
        on(host, '/usr/bin/gem uninstall facter', :accept_all_exit_codes => true)
      end
    end
  end
end
