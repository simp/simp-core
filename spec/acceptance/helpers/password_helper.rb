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

    end
  end
end
