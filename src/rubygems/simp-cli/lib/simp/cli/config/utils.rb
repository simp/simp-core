module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class PasswordError < StandardError; end
end

class Simp::Cli::Config::Utils
  DEFAULT_PASSWORD_LENGTH = 32
  class << self
    def validate_fqdn fqdn
      # snarfed from:
      #   https://www.safaribooksonline.com/library/view/regular-expressions-cookbook/9781449327453/ch08s15.html
      regex = %r{\A((?=[a-z0-9-]{1,63}\.)(xn--)?[a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,63}\Z}
      ((fqdn =~ regex) ? true : false )
    end


    def validate_ip ip
      # using the native 'resolv' class in order to minimize non-EL rubygems
      # snarfed from:
      # http://stackoverflow.com/questions/3634998/how-do-i-check-whether-a-value-in-a-string-is-an-ip-address
      require 'resolv'
      ((ip =~ Resolv::IPv4::Regex) || (ip =~ Resolv::IPv6::Regex)) ? true : false
    end


    def validate_hostname hostname
      # based on:
      #   http://stackoverflow.com/questions/2532053/validate-a-hostname-string
      #
      # nicer solution that only works on ruby1.9+:
      #   ( hostname =~  %r{\A(?!-)[a-z0-9-]{1,63}(?<!-)\Z} ) ? true : false
      #
      # ruby1.8-safe version:
      (( hostname =~  %r{\A[a-z0-9-]{1,63}\Z} ) ? true : false ) &&
       (( hostname !~ %r{^-|-$} ) ? true : false )
    end


    def validate_netmask( x )
      # a brute-force regexp that validates all possible valid netmasks
      nums = '(128|192|224|240|248|252|254)'
      znums = '(0|128|192|224|240|248|252|254)'
      regex = /^((#{nums}\.0\.0\.0)|(255\.#{znums}\.0\.0)|(255\.255\.#{znums}\.0)|(255\.255\.255\.#{znums}))$/i
      x =~ regex ? true: false
    end


    def validate_hiera_lookup( x )
      x.to_s.strip =~ %r@\%\{.+\}@ ? true : false
    end


    # NOTE: requires shell-based cracklib
    # TODO: should we find a better way of returning specific error messages than an exception?
    def validate_password( password )
      require 'shellwords'
      if password.length < 8
        raise Simp::Cli::Config::PasswordError, "Password must be at least 8 characters long"
        false
      else
        pass_result = `echo #{Shellwords.escape(password)} | cracklib-check`.split(':').last.strip
        if pass_result == "OK"
          true
        else
          raise Simp::Cli::Config::PasswordError, "Invalid Password: #{pass_result}"
          false
        end
      end
    end


    def generate_password( length = DEFAULT_PASSWORD_LENGTH )
      password = ''
      special_chars = ['#','%','&','*','+','-','.',':','@']
      symbols = ('0'..'9').to_a + ('A'..'Z').to_a + ('a'..'z').to_a
      Integer(length).times { |i| password += (symbols + special_chars)[rand((symbols.length-1 + special_chars.length-1))] }
      # Ensure that the password does not start or end with a special
      # character.
      special_chars.include?(password[0].chr) and password[0] = symbols[rand(symbols.length-1)]
      special_chars.include?(password[password.length-1].chr) and password[password.length-1] = symbols[rand(symbols.length-1)]
      password
    end


    # pure-ruby openldap hash generator
    def encrypt_openldap_hash( string, salt=nil )
       require 'digest/sha1'
       require 'base64'
       # Ruby 1.8.7 hack to do Random.new.bytes(4):
       salt = salt || (x = ''; 4.times{ x += ((rand * 255).floor.chr ) }; x)
       "{SSHA}"+Base64.encode64(
         Digest::SHA1.digest( string.to_s + salt.to_s )+ salt.to_s
       ).chomp
    end


    def validate_openldap_hash( x )
      (x =~ %r@\{SSHA\}[A-Za-z0-9=+/]+@ ) ? true : false
    end


    def generate_certificates(
          hostnames,
          ca_dir='/etc/puppet/environments/production/FakeCA'
        )
      result = true
      Dir.chdir( ca_dir ) do
        File.open('togen', 'w'){|file| hostnames.each{ |host| file.puts host }}

        # NOTE: script must exist in ca_dir
        result = system('./gencerts_nopass.sh auto') && result

        # blank file so subsequent runs don't re-key our hosts
        File.open('togen', 'w'){ |file| file.truncate(0) }
      end
      result
    end
  end
end
