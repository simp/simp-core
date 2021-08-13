module Acceptance
  module Helpers
    module PasswordHelper
      # NOTE:  These passwords will be enclosed in single quotes when used on
      #        the shell command line. So, to simplify the code that uses
      #        them, these passwords should not contain single quotes.
      TEST_PASSWORD_HASH = {
        :root      => 'P@ssw0rdP@ssw0rd',
        :grub      => 'Gru6=Us3r=P@ssw0rd',
        :ldap_root => 'Ld@P=R00t=P@ssw0rd',
        :user      => [ 'F1rst=Us3r=P@ssw0rd', 'Pwd=Aft3r=A=Ch@ng3', 'Y3t=An0th3r=Us3r=Pwd' ]
      }

      # Returns the plain-text, test password for the type and index specified
      #
      # @param type   The password type: :root, :grub, :ldap_root, :user
      # @param index  The array index of the password for password types that
      #   support multiple values. Currently, only applies to :user passwords.
      #
      def test_password(type, index=0)
        case type
        when :root, :grub, :ldap_root
          TEST_PASSWORD_HASH[type]
        when :user
          TEST_PASSWORD_HASH[type][index]
        else
          nil
        end
      end

      # Returns encrypted password appropriate for 389ds accounts instance
      #
      # @param ldap_server  Host on which the 389ds accounts instance resides
      # @param password  Plain text password to be encrypted
      #
      # Fails if the pwdhash command does not exist or the 389ds accounts
      # instance configuration does not exist
      #
      def encrypt_389ds_password(ldap_server, password)
        result = on(ldap_server, "pwdhash -D /etc/dirsrv/slapd-accounts '#{password}'")
        result.stdout.strip
      end

      # Returns encrypted password appropriate for type of LDAP server residing
      # on the LDAP host
      #
      # @param ldap_server  Host on which the LDAP server resides
      # @param password  Plain text password to be encrypted
      #
      def encrypt_ldap_password(ldap_server, password)
        if (fact_on(ldap_server, 'operatingsystemmajrelease') == '7')
          encrypt_openldap_password(password)
        else
          encrypt_389ds_password(ldap_server, password)
        end
      end

      # Returns encrypted password appropriate for openldap
      #
      # @param password  Plain text password to be encrypted
      #
      # lifted from rubygem-simp-cli
      def encrypt_openldap_password(password)
         require 'digest/sha1'
         require 'base64'

         # Ruby 1.8.7 hack to do Random.new.bytes(4):
         salt   = salt || (x = ''; 4.times{ x += ((rand * 255).floor.chr ) }; x)
         salt.force_encoding('UTF-8') if salt.encoding.name == 'ASCII-8BIT'

         digest = Digest::SHA1.digest( password + salt )

         # NOTE: Digest::SHA1.digest in Ruby 1.9+ returns a String encoding in
         #       ASCII-8BIT, whereas all other Strings in play are UTF-8
         digest.force_encoding('UTF-8') if digest.encoding.name == 'ASCII-8BIT'

         "{SSHA}"+Base64.encode64( digest + salt ).chomp
      end

      # returns encrypted grub password
      #
      # @param host Host on which the grub password will be generated via
      #   grub2-mkpasswd-pbkdf2
      #
      # @param password  Plain text password to be encrypted
      #
      # lifted from rubygem-simp-cli
      def encrypt_grub_password(host, password)
        on(host, "grub2-mkpasswd-pbkdf2 <<EOM\n#{password}\n#{password}\nEOM").stdout.split.last
      end
    end
  end
end
