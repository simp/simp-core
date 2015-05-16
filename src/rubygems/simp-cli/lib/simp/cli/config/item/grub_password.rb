require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end


# NOTE: EL used GRUB 0.9 up through EL6. EL7 moved to Grub 2.0
# NOTE: The two versions of GRUB use completely different configurations (files, encryption commands, etc)
module Simp::Cli::Config
  class Item::GrubPassword < PasswordItem
    include Simp::Cli::Config::SafeApplying

    def initialize
      super
      @key         = 'grub::password'
      @description = %Q{The password to access GRUB}
    end


    def validate string
      !string.to_s.strip.empty? && super
    end


    def encrypt string
      result   = nil
      password = string
      if Facter.value('lsbmajdistrelease') > '6'
        result = `grub2-mkpasswd-pbkdf2 <<EOM\n#{password}\n#{password}\nEOM`.split.last
      else
        require 'digest/sha2'
        salt   = rand(36**8).to_s(36)
        result = password.crypt("$6$" + salt)
      end
      result
    end


    def apply
      if Facter.value('lsbmajdistrelease') > "6" then
        # TODO: beg team hercules to make a augeas provider for grub2 passwords?
        `sed -i 's/password_pbkdf2 root/password_pbkdf2 root #{@value}/' /etc/grub.d/01_users`
        `grub2-mkconfig -o /etc/grub2.cfg`
      else
        `sed -i '/password/ c\password --encrypted #{@value}' /boot/grub/grub.conf`
      end
    end
  end
end
