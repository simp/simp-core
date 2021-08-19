module Acceptance
  module Helpers
    module PasswordHelper
      # NOTE:  These passwords will be enclosed in single quotes when used on
      #        the shell command line. So, to simplify the code that uses
      #        them, these passwords should not contain single quotes.
      TEST_PASSWORDS = [ "P@ssw0rdP@ssw0rd", "Ch@ng3d=P@ssw0r!" ]

      # Returns the plain-text, test password for the index specified
      #
      def test_password(index = 0)
        TEST_PASSWORDS[index]
      end

      # returns encrypted password appropriate for openldap
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
      # lifted from rubygem-simp-cli
      def encrypt_grub_password(host, password)
        on(host, "grub2-mkpasswd-pbkdf2 <<EOM\n#{password}\n#{password}\nEOM").stdout.split.last
      end

    end
  end
end
