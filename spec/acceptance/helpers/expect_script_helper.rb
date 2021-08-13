module Acceptance
  module Helpers
    module ExpectScriptHelper

      # location of the installed expect scripts
      EXPECT_SCRIPT_DIR = '/usr/local/bin'

      # Adjust ssh expect script command to address ssh cipher mismatch between
      # the source host and the destination host
      #
      # Adds ssh cipher option as the last command line argument to the ssh
      # expect script command, when a cipher mismatch needs to be addressed.
      #
      # * The expect script adds its last command line argument to ssh command
      #   it is executing.
      #
      # >>> FIXME: This is a workaround for SIMP-5082, which is OBE, as we <<<
      # >>> are no longer supporting EL6. Will leave this as a placeholder <<<
      # >>> for any other cipher mismatches that arise.                    <<<
      #
      # Returns the expect command
      def adjust_ssh_ciphers_for_expect_script(expect_cmd, src_host, dest_host)
        cmd = expect_cmd.dup
        src_os_major  = fact_on(src_host, 'operatingsystemmajrelease')
        dest_os_major = fact_on(dest_host, 'operatingsystemmajrelease')
        if src_os_major.to_s == '7'
          cmd +=" '-o MACs=hmac-sha1'" if (dest_os_major.to_s == '6')
        end
        cmd
      end

      # Installs an expect script onto a host
      #
      # +host+: Host (object) on which the expect script will be installed
      # +script+: Path to the expect script
      # +dest_dir+: Destination directory into which the expect script
      #   will be installed
      #
      # @returns the location of the script on the host
      def install_expect_script(host, script, dest_dir = EXPECT_SCRIPT_DIR)
        host.install_package('expect')
        dest_script = File.join(dest_dir, File.basename(script))
        scp_to(host, script, dest_script)
        on(host, "chmod +x #{dest_script}")
        dest_script
      end

    end
  end
end
