require_relative '../helpers'

include Acceptance::Helpers::PuppetHelper
include Acceptance::Helpers::RsyslogHelper
include Acceptance::Helpers::Utils

# The rsyslog and simp_rsyslog module acceptance tests verify the plumbing
# of rsyslog connectivity.  However, for the most part, those tests mock
# message sending using 'logger', and thus do not ensure logging on a SIMP
# system is complete/accurate.  We attempt to address this testing deficiency
# here by stimulating applications to generate events of interest, and then
# verifying actual application messages get logged locally and remotely, as
# expected.
#
# NOTES:
# 1) This test assumes rsyslog logging and forwarding has already been
#    configured.
# 2) Although this integration test is essential, it is unfortunately
#    fragile, as the applications managed and their syslog message
#    identities, levels, and content are all subject to change.
#
#    >>> This means this test code, and possibly simp_rsyslog, <<<
#    >>> may need to be updated when applications are updated. <<<
#
# 3) In most cases, messages from a syslog server, itself, that would
#    have been forwarded if the host was not a syslog server, are written
#    to /var/log/hosts/<syslog server fqdn>/, instead of the local file
#    to which other hosts write their messages.
#    - For code simplicity, these logs are verified along with other
#      forwarded logs in the test code.
# 4) FIXME: rsyslog forwarding rarely works when run on slow servers (e.g.,
#    some of the GitLab runners).
#    a) Don't have a mechanism to force rsyslog to flush its cache.
#       - Have tried test workarounds such as restarting the rsyslog server,
#         but these workarounds do not solve the problem and are disabled by
#         default.
#    b) In order to allow testing to continue, the tests are allowed to fail.
#       and each failure is converted into a skip
#
#       >>> The log forwarding that could not be verified in each skipped <<<
#       >>> test has to be verified manually prior to a SIMP release.     <<<
#
#    c) Have had problems with auditd logs not being forwarded and the
#       only solution is to restart auditd.
#       - Periodically, we should check if this workaround is still required.
#
# 5) SIMP-3480: There are numerous inconsistencies in the names of local and
#    remote logs, and into which local/remote log messages are written.
#    The tests are written for the *current* rsyslog configuration, not the
#    *desired* rsyslog configuration.
# 6) More tests need to be done...Notes can be found in a
#    commented out block at the end of the file.
#

shared_examples 'SIMP Rsyslog Tests' do |syslog_servers, non_syslog_servers, options|

  domain = options[:domain]
  scenario = options[:scenario]
  puppetserver = options[:master]

  let(:files_dir) { 'spec/acceptance/common_files' }

  let(:site_module_path) {
    '/etc/puppetlabs/code/environments/production/modules/site'
  }

  let(:original_default_hieradata) {
    default_yaml_filename = '/etc/puppetlabs/code/environments/production/data/default.yaml'
    YAML.load(on(puppetserver, "cat #{default_yaml_filename}").stdout)
  }

  # Hieradata that sets up local users for tlog and sudo log testing and
  # local user access tests in '20_local_users_spec.rb'
  let(:default_hieradata) {
    hiera = original_default_hieradata.merge( {
      'simp::classes' => [ 'site::local_users' ]
    } )
    hiera
  }

  # Hieradata that adds an unknown class 'oops', in order to intentionally
  # cause a catalog compilation error
  let (:bad_default_hieradata) {
    hiera = default_hieradata.dup
    hiera['simp::classes'] = [ 'site::local_users', 'oops' ]
    hiera
  }

  # Hieradata that enables forwarding of audit log
  # - standard config drops audit log forwarding, because they are voluminous
  let (:forward_audit_logs_hieradata) {
    hiera = default_hieradata.dup
    hiera['auditd::config::audisp::syslog::drop_audit_logs'] = false
    hiera
  }

  context 'general test set up ' do
    it 'should install additional manifests' do
      scp_to(puppetserver, "#{files_dir}/site", site_module_path)
      on(puppetserver, 'simp environment fix production --no-secondary-env --no-writable-env')
    end

    it 'should rotate forwarded logs for clean test results' do
      on(syslog_servers, 'logrotate -f /etc/logrotate.simp.d/simp_rsyslog_server_profile')
    end

    it 'should rotate local logs for clean test results' do
      logrotate_files = [
        '/etc/logrotate.simp.d/aide',
        '/etc/logrotate.simp.d/syslog',
        '/etc/logrotate.simp.d/tlog'
      ]
      on(hosts, "logrotate -f #{logrotate_files.join(' ')}")
    end
  end

  context 'basic logs' do
    # For local and forwarded, non-error puppet agent logs
    # - Local puppet-agent.log files will contain all messages, but
    #   forwarded puppet_agent.log files will only contain messages
    #   up to the warn level.
    let(:puppet_warn_msg) { 'Not using cache on failed catalog' }

    # For puppet agent error logs, puppetserver error logs, and local
    # non-error puppetserver logs.
    # - Local puppetserver.log files will contain all messages, but
    #   forwarded puppetserver.log files will only contain messages
    #   up to the warn level
    let(:puppet_err_msg) { 'Could not find class ::oops ' }

    context 'puppet-related logs' do
      it 'should trigger logging events for puppet agent and puppetserver' do
        # puppet-agent.log messages will be generated with each puppet agent run.
        # However, to generate puppetserver.log, puppet-agent-err.log and
        # puppetserver-err.log messages, add an unknown class 'oops' to the
        # default.yaml
        set_default_yaml(puppetserver, bad_default_hieradata)
        on(hosts, 'puppet agent -t', :accept_all_exit_codes => true)
      end

      it 'should generate local puppet agent logs' do
        success = verify_local_log_messages(puppet_warn_msg,
          '/var/log/puppet-agent.log', non_syslog_servers)

        success &= verify_local_log_messages(puppet_err_msg,
          '/var/log/puppet-agent-err.log', non_syslog_servers)

        unless success
          err_msg = 'Not all local puppet agent logs were generated'
          handle_local_log_failures(self.class.description, err_msg)
        end
      end

      it 'should generate local puppetserver logs' do
        success = verify_local_log_messages(puppet_err_msg,
          '/var/log/puppetserver.log', puppetserver)

        success &= verify_local_log_messages(puppet_err_msg,
          '/var/log/puppetserver-err.log', puppetserver)

        unless success
          err_msg = 'Not all local puppetserver logs were generated'
          handle_local_log_failures(self.class.description, err_msg)
        end
      end

      it 'should forward puppet agent logs' do
        success = verify_remote_log_messages(puppet_warn_msg,
          'puppet_agent.log', hosts, syslog_servers, domain)

        success &= verify_remote_log_messages(puppet_err_msg,
          'puppet_agent_error.log', hosts, syslog_servers, domain)

        unless success
          err_msg = 'Not all puppet agent logs were forwarded'
          handle_forward_log_failures(self.class.description, err_msg)
        end

      end

      it 'should forward puppetserver logs' do
        # TODO Figure out how to trigger puppetserver logs to be forwarded
        #success = verify_remote_log_messages(puppet_warn_msg,
        #  'puppetserver.log', puppetserver, syslog_servers, domain)

        success = verify_remote_log_messages(puppet_err_msg,
          'puppetserver_error.log', puppetserver, syslog_servers, domain)

        unless success
          err_msg = 'Not all puppetserver logs were forwarded'
          handle_forward_log_failures(self.class.description, err_msg)
        end
      end

      it 'should restore a valid default.yaml' do
        set_default_yaml(puppetserver, default_hieradata)
      end
    end

    context 'systemd logs' do
      let(:log_msg) { 'systemd.*: Reloading Postfix Mail Transport Agent' }
      it 'should trigger systemd logging events' do
        on(hosts, 'systemctl reload postfix.service')
      end

      it 'should generate systemd log messages in the local secure log' do
        success = verify_local_log_messages(log_msg, '/var/log/secure',
          non_syslog_servers)

        unless success
          err_msg = 'Not all local systemd logs with postfix reload were generated'
          handle_local_log_failures(self.class.description, err_msg)
        end
      end

      it 'should forward systemd logs' do
        success = verify_remote_log_messages(log_msg, 'secure.log',
           hosts, syslog_servers, domain)

        unless success
          err_msg = 'Not all systemd logs were forwarded'
          handle_forward_log_failures(self.class.description, err_msg)
        end
      end
    end

    context 'package manager logs' do
      let(:log_msg) { 'Installed: expect' }
      hosts.each do |host|
        it "should trigger package manager logging events on #{host}" do
          host.install_package('expect')
        end

        unless host.host_hash[:roles].include?('syslog_server')
          it "should generate a local package manager log on #{host}" do
            package_manager_log = host.which('dnf').empty? ? '/var/log/yum.log' : '/var/log/dnf.rpm.log'
            success = verify_local_log_messages(log_msg, package_manager_log, host)

            unless success
              err_msg = "package manager local logs were not generated on #{host}"
              handle_local_log_failures(self.class.description, err_msg)
            end
          end
        end

        # /var/log/dnf.rpm.log not yet forwarded (SIMP-10413)
        if host.which('dnf').empty?
          it "should forward package manager logs from #{host}" do
            success = verify_remote_log_messages(log_msg, 'secure.log',
              host, syslog_servers, domain)

            unless success
              err_msg = "Not all package manager logs from #{host} were forwarded"
              handle_forward_log_failures(self.class.description, err_msg)
            end
          end
        end
      end
    end

    context 'cron logs' do
      let(:cron_entry) { 'ls /tmp' }
      let(:cron_msg) { "CROND.*: .root. CMD .#{cron_entry}" }
      let(:test_cron_manifest) {
        <<~EOM
          cron { 'rsyslog_beaker':
            user    => 'root',
            minute  => '*',
            command => '#{cron_entry}'
          }
        EOM
      }

      let(:remove_test_cron_manifest) {
       "cron { 'rsyslog_beaker': ensure=> absent }"
      }

      it 'should create the test cron job' do
        hosts.each do |host|
          apply_manifest_on(host, test_cron_manifest)
        end
      end

      it 'should generate a local cron log' do
        success = verify_local_log_messages( cron_msg, '/var/log/cron',
          non_syslog_servers,
          # cron job may take up 1 minute to run, so give it time to run and log
          {:retry_interval => 5, :max_retries => 15}
        )

        unless success
          err_msg = 'Not all local cron logs were generated'
          handle_local_log_failures(self.class.description, err_msg)
        end
      end

      it 'should forward cron logs' do
        success = verify_remote_log_messages(cron_msg, 'cron.log',
          hosts, syslog_servers, domain,
          # cron job may take up 1 minute to run, so give time to run and log
          {:retry_interval => 5, :max_retries => 15}
        )

        unless success
          err_msg = 'Not all cron logs were forwarded'
          handle_forward_log_failures(self.class.description, err_msg)
        end
      end

      it 'should remove test cron job' do
        hosts.each do |host|
          apply_manifest_on(host, remove_test_cron_manifest)
        end
      end

      it "should forward 'crond' identity logs" do
        # When you restart the crond service, its shutdown logs go to secure.log,
        # locally, but <host>/cron.log on the remote server.  This inconsistency
        # is not ideal, but, as the logs are not lost, is not a show stopper.
        skip('crond logs end up in <host>/cron.log, not <host>/secure.log')
      end
    end

    context 'boot logs' do
      # Per rsyslog and simp_rsyslog config:
      # Local server:         local7.*      => /var/log/boot.log
      # Forward rule(?):      local7.warn (and above)
      # Remote syslog server: boot identity => /var/log/host/<host>/boot.log
      it "should forward 'boot' identity logs" do
        # Rebooting machine doesn't result in messages with identity 'boot' being
        # forwarded to the remote syslog server
        # FIXME
        # - Is the boot identity appropriate?
        # - Should the boot identity be added to the forwarding rule or is
        #   local7.warn sufficient?
        # - Should the remote syslog server rule be local7.*, instead of
        #   boot identity?
        skip('Unable to generate appropriate logs for forwarding')
     end
    end
  end

  context 'security application logs' do
    context 'aide logs' do
      let(:log_msg) { 'found differences between database and filesystem' }

      it 'should trigger aide logging events' do
        # since we haven't updated the aide database but have made many changes
        # by installing packages, some aide should detect the changes
        on(hosts, '/usr/sbin/aide -C', :accept_all_exit_codes => true)
      end

      it 'should generate aide a local aide log' do
        success = verify_local_log_messages(log_msg, '/var/log/aide/aide.log',
          non_syslog_servers)

        unless success
          err_msg = 'Not all local aide logs were generated'
          handle_local_log_failures(self.class.description, err_msg)
        end
      end

      it 'should forward aide logs' do
        success = verify_remote_log_messages(log_msg, 'aide.log',
           hosts, syslog_servers, domain)

        unless success
          err_msg = 'Not all aide logs were forwarded'
          handle_forward_log_failures(self.class.description, err_msg)
        end
      end
    end

    if scenario == 'simp'
      context 'firewall logs' do
        let(:firewall_logs) { {
          :firewalld => {
            :message => 'kernel: IN_99_simp_DROP:',
            :log     => '/var/log/firewall.log'
          },
          :iptables  => {
            :message => 'kernel: IPT:',
            :log     => '/var/log/iptables.log'
          }
        } }

        it 'should generate firewall logging events with disallowed network traffic' do
          hosts.each { |host| host.install_package('wget') }

          # None of the servers are set up as web servers, yet, so attempting
          # web access to these servers should result in dropped packet logs
          non_syslog_servers.each do |host|
            cmd = "wget --tries=1 --timeout=1 https://#{host.name}.#{domain}/somefile"
            on(syslog_servers, cmd, :accept_all_exit_codes => true)
          end

          syslog_servers.each do |host|
            cmd = "wget --tries=1 --timeout=1 https://#{host.name}.#{domain}/somefile"
            on(non_syslog_servers.first, cmd, :accept_all_exit_codes => true)
          end
        end

        non_syslog_servers.each do |host|
          it "should generate a local firewall log on #{host}" do
            firewalld_state = YAML.load(on(host, 'puppet resource service firewalld --to_yaml').stdout.strip).dig('service','firewalld','ensure')

            info = (firewalld_state == 'running') ? firewall_logs[:firewalld] : firewall_logs[:iptables]
            success = verify_local_log_messages(info[:message], info[:log], host)

            unless success
              err_msg = "firewall local logs were not generated on #{host}"
              handle_local_log_failures(self.class.description, err_msg)
            end
          end
        end

        hosts.each do |host|
          it "should forward firewall dropped packet logs from #{host}" do
            firewalld_state = YAML.load(on(host, 'puppet resource service firewalld --to_yaml').stdout.strip).dig('service','firewalld','ensure')

            info = (firewalld_state == 'running') ? firewall_logs[:firewalld] : firewall_logs[:iptables]
            success = verify_remote_log_messages(info[:message], File.basename(info[:log]), host,
              syslog_servers, domain)

            unless success
              err_msg = "Not all firewall logs from #{host} were forwarded"
              handle_forward_log_failures(self.class.description, err_msg)
            end
          end
        end
      end
    end

    context 'root access logs' do
      let(:tlog_msg) { 'tlog-rec-session.*: .*,"user":"root",' }
      let(:sudo_msg) { 'sudo: localadmin : .* COMMAND=.*/su - root' }
      let(:user_pwd) { test_password(:user, 0) }

      it 'should create privileged local user' do
        # The privileged local user is created via site::local_users.
        set_default_yaml(puppetserver, default_hieradata)
        on(hosts, 'puppet agent -t', :accept_all_exit_codes => true)

        # Before the user can login, we need to set the user's password
        on(hosts, "echo '#{user_pwd}' | passwd localadmin --stdin")
      end

      it 'should trigger logging events for tlog and sudo' do
        # This log-generating step will use an expect script that does the following
        # - ssh's to a host as a local user configured with no password sudo privileges
        # - runs 'sudo su - root'
        # - as root
        #   - executes a root-level command
        #   - echos messages to the console to trigger tlog to flush its cache
        #
        # NOTE: The ssh source server is arbitrarily selected to be the puppetserver.
        #
        remote_script = install_expect_script(puppetserver, "#{files_dir}/ssh_sudo_su_root_script")
        hosts.each do |host|
          base_cmd ="#{remote_script} localadmin #{host.name} #{user_pwd}"
          cmd = adjust_ssh_ciphers_for_expect_script(base_cmd, puppetserver, host)
          on(puppetserver, cmd)
        end
      end

      it 'should generate a local tlog.log' do
        success = verify_local_log_messages(tlog_msg, '/var/log/tlog.log',
          non_syslog_servers)

        unless success
          err_msg = 'Not all local tlog logs were generated'
          handle_local_log_failures(self.class.description, err_msg)
        end
      end

      it 'should forward tlog logs' do
        success = verify_remote_log_messages(tlog_msg, 'tlog.log',
           hosts, syslog_servers, domain)

        unless success
          err_msg = 'Not all tlog logs were forwarded'
          handle_forward_log_failures(self.class.description, err_msg)
        end
      end

      it 'should generate sudo messages in the local secure log' do
        success = verify_local_log_messages(sudo_msg,
          '/var/log/secure', non_syslog_servers)

        unless success
          err_msg = 'Not all local sudo logs were generated'
          handle_local_log_failures(self.class.description, err_msg)
        end
      end

      it 'should forward sudo logs' do
        success = verify_remote_log_messages(sudo_msg, 'secure.log',
           hosts, syslog_servers, domain)

        unless success
          err_msg = 'Not all sudo logs were forwarded'
          handle_forward_log_failures(self.class.description, err_msg)
        end
      end
    end

    context 'audit logs' do
      let(:audit_msg) { 'type=SYSCALL .*/chcon' }
      let(:auditd_msg) { 'auditd\\[[0-9]+\\]: ' }

      it 'should enable audit log forwarding' do
        set_default_yaml(puppetserver, forward_audit_logs_hieradata)
        on(hosts, 'puppet agent -t', :accept_all_exit_codes => true)

        # FIXME: Workaround for SIMP-5161 bug
        restart_rsyslog(hosts)
      end

      it 'should trigger audit logging events' do
        # Generate audit records by changing the selinux context of a file.
        # Since we don't want to screw anything up, first create a file
        # in root's home dir and then change its context.
        on(hosts, 'date > /root/date.txt')
        on(hosts, 'ls -Z /root/date.txt')
        on(hosts, 'chcon --user system_u /root/date.txt')
        on(hosts, 'chcon --user unconfined_u /root/date.txt')
      end

      it 'should generate a local audit.log' do
        # NOTE: this is found on all servers, even syslog servers
        success = verify_local_log_messages(audit_msg,
          '/var/log/audit/audit.log', hosts)

        unless success
          err_msg = 'Not all local audit logs were generated'
          handle_local_log_failures(self.class.description, err_msg)
        end
      end

      it 'should forward audit logs' do
        success = verify_remote_log_messages(audit_msg, 'auditd.log',
           hosts, syslog_servers, domain)

        unless success
          # restart auditd and try again
          $stderr.puts '>'*80
          $stderr.puts 'WARNING: Failed to forward audit logs.'
          $stderr.puts 'WARNING: Restarting auditd and retrying.'

          # auditd is an odd one...can't be restarted with systemctl
          on(hosts, 'service auditd restart')

          # redo some chcon operations
          on(hosts, 'chcon --user system_u /root/date.txt')
          on(hosts, 'chcon --user unconfined_u /root/date.txt')

          success = verify_remote_log_messages(audit_msg, 'auditd.log',
             hosts, syslog_servers, domain)

          unless success
            $stderr.puts '#'*80
            $stderr.puts 'Restart of auditd did not allow audit logs to be forwarded'
            $stderr.puts '#'*80
            err_msg = 'Not all auditd logs were forwarded'
            handle_forward_log_failures(self.class.description, err_msg)
          end
        end
      end

      it 'should trigger auditd logging event' do
        # auditd is an odd one...can't be restarted with systemctl
        on(hosts, 'service auditd restart')
      end

      it 'should generate auditd messages in the local secure log' do
        success = verify_local_log_messages(auditd_msg,
          '/var/log/secure', non_syslog_servers)

        unless success
          err_msg = 'Not all local auditd logs were generated'
          handle_local_log_failures(self.class.description, err_msg)
        end
      end

      it 'should forward auditd logs' do
        success = verify_remote_log_messages(auditd_msg, 'secure.log',
           hosts, syslog_servers, domain)

        unless success
          err_msg = 'Not all auditd logs were forwarded'
          handle_forward_log_failures(self.class.description, err_msg)
        end
      end

      # Turn off audit forwarding for future tests, as it can be prolific
      it 'should disable audit log forwarding' do
        set_default_yaml(puppetserver, original_default_hieradata)
        on(hosts, 'puppet agent -t', :accept_all_exit_codes => true)

        # FIXME: Workaround for SIMP-5161 bug
        restart_rsyslog(hosts)
      end

      it "should forward 'audit' identity logs" do
        # Don't know how to stimulate auditd to create such logs
        # (TODO Is forwarding rule OBE?)
        skip('Unable to generate appropriate logs for forwarding')
      end
    end

    context 'rkhunter logs' do
      # FIXME
      # - Scans can be triggered by the puppet_rkhunter_check.service, but take
      #   >3 minutes to run.
      # - SIMP-10422 Detailed scan results are not forwarded to the rsyslog
      #   server. So, only way to check for rkhunter is to look for the systemd
      #   messages about puppet_rkhunter_check.service, which would be logged
      #   to /var/log/secure and its corresponding
      #   /var/log/hosts/<host fqnd>/secure.log file
      it 'should generate rkhunter logs' do
        skip('puppet_rkhunter_check.service execution takes over 3 minutes')
      end
    end
  end

=begin
  context 'other important application logs' do
# Some other logs for which we have rules generated from SIMP modules
#
# Log Type                 Local Log                  Remote Host-specific Log
# emergency logs (*.emerg) /var/log/secure            /var/log/host/<host>/emergency.log
# kernel logs (kern.*)     No match                   /var/log/host/<host>/kernel.log
# dhcpd logs               /var/log/dhcpd.log         /var/log/host/<host>/dhcpd.log
# httpd error logs         /var/log/httpd/error_log   /var/log/host/<host>/httpd_error.log
# httpd non-error logs     /var/log/httpd/access_log  /var/log/host/<host>/httpd.log
# mail logs                /var/log/maillog           /var/log/host/<host>/mail.log
# snmpd logs               /var/log/snmpd.log         /var/log/host/<host>/snmpd.log
# slapd audit logs         /var/log/slapd_audit.log   /var/log/host/<host>/slapd_audit.log
# spool logs               /var/log/spooler           /var/log/host/<host>/spool.log
# any other *.info and     N/A                        /var/log/host/<host>/messages.log
#   above forwarded
#   messages that have
#   no specific dest file
# catchall for remaining   N/A                        /var/log/host/<host>/catchall.log
#   forwarded messages that
#   have no specific dest
#   file and don't make it
#   into /var/log/host/<host>/messages.
  end
=end

end

