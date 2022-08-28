# frozen_string_literal: true

module Acceptance
  module Helpers
    module SystemGemHelper
      def install_system_factor_gem(host)
        host.install_package('rubygems')
        # Facter 4.0 needs ruby 2.3 or later and system ruby on EL7
        # is version 2.0.0
        on(host, '/usr/bin/gem install facter || /usr/bin/gem install facter --version "<4.0.0"')

        # Facter 2 hangs on EC2 fact if not on a cloud system
        result = on(host, 'timeout 5 facter networking', :accept_all_exit_codes => true)
        unless result.exit_code == 0
          # The EC2 fact is hanging due to a bug in facter 2, kill it with fire
          on(host, %{find $( gem env gemdir ) -name ec2.rb | grep -e facter | xargs -r rm})
        end

        # beaker-helper fact_on() now uses '--json' on facter calls, so
        # we need to make sure the json gem is installed
        result = on(host, 'facter --json fqdn', :accept_all_exit_codes => true)
        return if result.exit_code.eql?(0)

        # We have old system Ruby (1.8.7) which does not include json.  So,
        # install the pure-Ruby version of json.
        on(host, "gem install json_pure || gem install json_pure --version '<2.0.0'")
      end

      def uninstall_system_factor_gem(host)
        on(host, '/usr/bin/gem uninstall -x facter', :accept_all_exit_codes => true)
      end
    end
  end
end
