module Acceptance
  module Helpers
    module IpaHelper

      # NOTE:  The passwords below will be enclosed in single quotes when used
      #        on the shell command line. So, to simplify the code that uses
      #        them, these passwords should not contain single quotes.

      # returns IPA 'admin' password
      def ipa_admin_password
        'ipA=@dm1n=P@ssw0r!'
      end

      # returns IPA directory service password
      def ipa_directory_service_password
        'd1r3ct0ry=P@ssw0r!'
      end

      # returns one-time enrollment passwords assigned to all hosts
      def ipa_bulk_enroll_password
        'en0llm3nt=p@ssWor^'
      end

      # execute an IPA command with 'admin' privileges
      # +host+: the IPA Host object
      # +cmd+:  the command to be executed
      def run_ipa_cmd(host, cmd)
        on(host, "echo \"#{ipa_admin_password}\" | kinit admin")
        result = on(host, cmd)
        on(host, 'kdestroy')

        result
      end

    end
  end
end
