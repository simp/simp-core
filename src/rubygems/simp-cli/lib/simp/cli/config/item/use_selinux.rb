require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::UseSELinux < Item
    def initialize
      super
      @key         = 'selinux::ensure'
      @fact        = 'selinux_current_mode'
      @description = %Q{SELinux is good.

Not all modules are compatible with SELinux in enforcing mode but the core
SIMP modules are. You should not take this below 'permissive' unless it is
truly necessary.}
    end

    def validate( x )
      (x.to_s =~ /permissive|disabled|enforcing/i ) ? true : false
    end

    def not_valid_message
      'Must be "enforcing," "permissive," or "disabled" (not recommended)'
    end

    def recommended_value
      os_value || 'enforcing'
    end
  end
end
