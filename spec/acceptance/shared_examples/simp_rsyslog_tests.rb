require_relative '../helpers'

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
# 1) Although this integration test is essential, it is unfortunately
#    fragile, as application syslog message identity, level, and content are
#    all subject to change.  This means the test, and possibly simp_rsyslog,
#    may need to be updated when applications are updated.
# 2) FIXME: rsyslog forwarding doesn't always work
#    a) Sometimes a restart of the rsyslog service on the remote rsyslog
#      servers is required in order for the messages to be forwarded.
#      Don't know why this happens sporadically. A test workaround has
#      been implemented to mitigate this.  However the test can still fail.
#    b) Have had problems with auditd logs not being forwarded and the
#       only solution is to restart auditd.  Examination of the auditd
#       source code does not show an obvious reason why the dispatch stops
#       working.  Events to the syslog dispatcher that can't be sent to syslog
#       are simply discarded and the syslog C api is being used normally...
#       A test workaround has been implemented to mitigate this.  However,
#       the test can still fail.
# 3) SIMP-3480: There are numerous inconsistencies in the names of local and
#    remote logs, and into which local/remote log messages are written.
#    The tests are written for the *current* rsyslog configuration, not the
#    *desired* rsyslog configuration.
# 4) In most cases, messages from a syslog server, itself, that would
#    have been forwarded if the host was not a syslog server, are written
#    to /var/log/hosts/<syslog server fqdn>, instead of the local file
#    to which other hosts write their messages. This provides consistency
#    for the sysadmins examining host logs on the syslog server.
# 5) More tests need to be done...Notes can be found in a
#    commented out block at the end of the file.
#

shared_examples 'SIMP Rsyslog Tests' do |syslog_servers, non_syslog_servers, options|

domain = options[:domain]
scenario = options[:scenario]
master = options[:master]


  let(:files_dir) { 'spec/acceptance/common_files' }

  let(:default_yaml_filename) {
    '/etc/puppetlabs/code/environments/production/data/default.yaml'
  }

  let(:site_module_path) {
    '/etc/puppetlabs/code/environments/production/modules/site'
  }

  let(:original_default_hieradata) {
    YAML.load(on(master, "cat #{default_yaml_filename}").stdout)
  }

  let(:default_hieradata) {
    hiera = original_default_hieradata.merge( {
      # to ensure all hosts have a cron that runs every minute for a test below
      'swap::cron_step'             => 1,

      # set up local users for further testing
      'classes'                     => [ 'site::local_users' ]
    } )
    hiera
  }

  let (:bad_default_hieradata) {
    hiera = default_hieradata.dup
    # unknown class 'oops'
    hiera['classes'] = [ 'site::local_users', 'oops' ]
    hiera
  }

  let (:forward_audit_logs_hieradata) {
    hiera = default_hieradata.dup
    hiera['auditd::config::audisp::syslog::drop_audit_logs'] = false
    hiera
  }

  context 'additional site manifest/hieradata staging' do
    it 'should install additional manifests and update hieradata' do
      scp_to(master, "#{files_dir}/site", site_module_path)
      on(master, 'simp environment fix production --no-secondary-env --no-writable-env')

      create_remote_file(master, default_yaml_filename, default_hieradata.to_yaml)
    end
  end

  context 'basic logs' do
    it 'should generate local puppet agent and puppet server logs' do
      on(hosts, 'puppet agent -t', :accept_all_exit_codes => true)

      # To force an error, add an unknown class 'oops' to the default.yaml
      create_remote_file(master, default_yaml_filename, bad_default_hieradata.to_yaml)
      on(hosts, 'puppet agent -t', :accept_all_exit_codes => true)

      # Restore valid default.yaml
      create_remote_file(master, default_yaml_filename, default_hieradata.to_yaml)

      on(non_syslog_servers, "grep 'Applied catalog in' /var/log/puppet-agent.log")
      on(non_syslog_servers, "grep 'Could not find class ::oops ' /var/log/puppet-agent-err.log")

      on(master, "ls /var/log/puppetserver.log")
      on(master, "grep 'Could not find class ::oops ' /var/log/puppetserver-err.log")
    end

    it 'should forward puppet agent logs' do
      begin
        verify_remote_log_messages(['Applied catalog in'], 'puppet_agent.log', hosts, domain)
        verify_remote_log_messages(['Could not find class ::oops '], 'puppet_agent_error.log',
          hosts, domain)
      rescue Beaker::Host::CommandFailure => e
        skip "#{self.class.description} failed => #{e}"
      end
    end

    it 'should forward puppetserver logs' do
      retried = false
      begin
        logdir = "/var/log/hosts/#{master.name}.#{domain}"
        on(syslog_servers, "ls #{logdir}")
        on(syslog_servers, "grep 'Could not find class ::oops ' #{logdir}/puppetserver_error.log")
      rescue Beaker::Host::CommandFailure => e
        handle_failed_message_forwarding(e, retried, syslog_servers)
        retried = true
        retry
      end
    end

    it 'should generate systemd log messages in the local secure log' do
      hosts.each do |host|
        if pfact_on(host, 'systemd')
          on(host, 'systemctl restart haveged.service')
          sleep(20)

          unless host.host_hash[:roles].include?('syslog_server')
            on(host, "grep 'systemd.*: Stopping Entropy Daemon based on the HAVEGE' /var/log/secure")
            on(host, "grep 'systemd.*: Start.* Entropy Daemon based on the HAVEGE' /var/log/secure")
          end
        else
          puts "Skipping host #{host.name}, which does not use systemd"
        end
      end
    end

    it 'should forward systemd logs' do
      retried = false
      begin
        hosts.each do |host|
          if pfact_on(host, 'systemd')
            logdir = "/var/log/hosts/#{host.name}.#{domain}"
            on(syslog_servers, "grep 'systemd.*: Stopping Entropy Daemon based on the HAVEGE' #{logdir}/secure.log")
            on(syslog_servers, "grep 'systemd.*: Start.* Entropy Daemon based on the HAVEGE' #{logdir}/secure.log")
          else
            puts "Skipping host #{host.name}, which does not use systemd"
          end
        end
      rescue Beaker::Host::CommandFailure => e
        handle_failed_message_forwarding(e, retried, syslog_servers)
        retried = true
        retry
      end
    end

    hosts.each do |host|
      # DNF systems don't log to yum.log
      next if host.which('dnf')

      it 'should generate a local yum log' do
        skip "#{host} uses 'dnf'" if host.which('dnf')

        host.install_package('expect')
        unless host.host_hash[:roles].include?('syslog_server')
          on(host, "grep 'Installed: expect' /var/log/yum.log")
        end
      end

      it 'should forward yum logs' do
        skip "#{host} uses 'dnf'" if host.which('dnf')

        begin
          verify_remote_log_messages(['Installed: expect'], 'secure.log', host, domain)
        rescue Beaker::Host::CommandFailure => e
          skip "#{self.class.description} failed => #{e}"
        end
      end
    end

    context 'cron logs' do
      let(:cron_entry) { 'ls /tmp' }

      let(:cron_manifest) {
        <<~EOM
          cron { 'rsyslog_beaker':
            user    => 'root',
            minute  => '*',
            command => '#{cron_entry}'
          }
        EOM
      }

      it 'should create the test cron job' do
        hosts.each do |host|
          apply_manifest_on(host, cron_manifest)
        end
      end

      it 'should generate a local cron log' do
        non_syslog_servers.each do |host|
          retry_on(
            host,
            "egrep 'CROND.*: .root. CMD .#{cron_entry}' /var/log/cron",
            {:retry_interval => 5, :max_retries => 15}
          )
        end
      end

      it 'should forward cron logs' do
        begin
          verify_remote_log_messages(["CROND.*: .root. CMD .#{cron_entry}"], 'cron.log', hosts, domain)
        rescue Beaker::Host::CommandFailure => e
          skip "#{self.class.description} failed => #{e}"
        end
      end
    end

    it "should forward 'crond' identity logs" do
      # When you restart the crond service, its shutdown logs go to secure.log,
      # locally, but <host>/cron.log on the remote server.  This inconsistency
      # is not ideal, but, as the logs are not lost, is not a show stopper.
      skip('crond logs end up in <host>/cron.log, not <host>/secure.log')
    end

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
      # - Should the remote syslot server rule be local7.*, instead of
      #   boot identity?
      skip('Unable to generate appropriate logs for forwarding')
    end
  end

  context 'security application logs' do
    it 'should generate aide a local aide log' do
      on(hosts, '/usr/sbin/aide -C', :accept_all_exit_codes => true)
      # since we haven't updated the database but have made many changes,
      # some changes should be noted
      on(non_syslog_servers, "grep 'found differences between database and filesystem' /var/log/aide/aide.log")
    end

    it 'should forward aide logs' do
      begin
        verify_remote_log_messages(['found differences between database and filesystem'],
          'aide.log', hosts, domain)
      rescue Beaker::Host::CommandFailure => e
        skip "#{self.class.description} failed => #{e}"
      end
    end

    if scenario == 'simp'
      it 'should generate a local firewall log' do
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

        non_syslog_servers.each do |host|
          firewalld_state = YAML.load(on(host, 'puppet resource service firewalld --to_yaml').stdout.strip).dig('service','firewalld','ensure')

          if firewalld_state == 'running'
            on(host, "grep 'kernel: IN_99_simp_DROP:' /var/log/firewall.log")
          else
            on(host, "grep 'kernel: IPT:' /var/log/iptables.log")
          end
        end
      end

      it 'should forward firewall dropped packet logs' do
        begin
          hosts.each do |host|
            firewalld_state = YAML.load(on(host, 'puppet resource service firewalld --to_yaml').stdout.strip).dig('service','firewalld','ensure')

            if firewalld_state == 'running'
              verify_remote_log_messages(['kernel: IN_99_simp_DROP:'], 'firewall.log', [host], domain)
            else
              verify_remote_log_messages(['kernel: IPT:'], 'iptables.log', [host], domain)
            end
          end
        rescue Beaker::Host::CommandFailure => e
          skip "#{self.class.description} failed => #{e}"
        end
      end
    end

    it 'should generate a local tlog.log' do
      # This test will use an expect script that ssh's to a host as a
      # local user configured with no password sudo privileges, runs
      # 'sudo su - root', and then executes a root-level command.
      # Before the user can login, we need to set the user's password
      on(hosts, "echo '#{test_password}' | passwd localadmin --stdin")
      remote_script = install_expect_script(master, "#{files_dir}/ssh_sudo_su_root_script")
      hosts.each do |host|
        base_cmd ="#{remote_script} localadmin #{host.name} #{test_password}"

        # FIXME: Workaround for SIMP-5082
        cmd = adjust_ssh_ciphers_for_expect_script(base_cmd, master, host)
        begin
          on(master, cmd)

          unless host.host_hash[:roles].include?('syslog_server')
            on(host, "egrep '(tlog-rec-session|tlog): .*,.user.:.root.,' /var/log/tlog.log")
          end
        rescue => e
          skip "#{self.class.description} failed => #{e}"
        end
      end
    end

    it 'should forward tlog logs' do
      begin
        verify_remote_log_messages(
          [ '(tlog-rec-session|tlog): .*,.user.:.root.,' ],  'tlog.log',
          hosts, domain)
      rescue Beaker::Host::CommandFailure => e
        skip "#{self.class.description} failed => #{e}"
      end
    end

    it 'should generate sudo messages in the local secure log' do
      # The previous test should have generated sudo logs about 'sudo su - root'
      begin
        on(non_syslog_servers, "grep 'sudo: localadmin : .* COMMAND=.*/su - root' /var/log/secure")
      rescue => e
        skip "#{self.class.description} failed => #{e}"
      end
    end

    it 'should forward sudo logs' do
      begin
        verify_remote_log_messages(
          ['sudo: localadmin : .* COMMAND=.*/su - root'], 'secure.log',
          hosts, domain)
      rescue Beaker::Host::CommandFailure => e
        skip "#{self.class.description} failed => #{e}"
      end
    end

    it 'should enable audit log forwarding' do
      create_remote_file(master, default_yaml_filename, forward_audit_logs_hieradata.to_yaml)
      on(hosts, 'puppet agent -t', :accept_all_exit_codes => true)

      # FIXME: Workaround for SIMP-5161 bug
      restart_rsyslog(hosts)
    end

    it 'should generate a local audit.log' do
      # Generate audit records by changing the selinux context of a file.
      # Since we don't want to screw anything up, first create a file
      # in root's home dir and then change its context.
      on(hosts, 'date > /root/date.txt')
      on(hosts, 'ls -Z /root/date.txt')
      on(hosts, 'chcon --user system_u /root/date.txt')
      on(hosts, 'chcon --user unconfined_u /root/date.txt')
      on(hosts, "grep 'type=SYSCALL .*/chcon' /var/log/audit/audit.log")
    end

    it 'should forward audit logs' do
      retried = false
      begin
        verify_remote_log_messages(['type=SYSCALL .*/chcon'], 'auditd.log', hosts, domain)
      rescue Beaker::Host::CommandFailure => e
        if retried
          $stderr.puts '#'*80
          $stderr.puts 'Restart of auditd did not allow audit logs to be forwarded'
          $stderr.puts '#'*80
          skip "#{self.class.description} failed => #{e}"
        end

        $stderr.puts '>'*80
        $stderr.puts 'WARNING: Failed to forward audit logs.'
        $stderr.puts 'WARNING: Restarting auditd and retrying.'
        # Have had problems with this that I haven't able to track down.
        # Examination of the auditd source code does not show an obvious reason
        # why the dispatch stops working.  Events to the syslog dispatcher that
        # can't be sent to syslog are simply discarded and the syslog C api is
        # being used normally...
        on(hosts, 'service auditd restart')

        # redo some chcon operations
        on(hosts, 'chcon --user system_u /root/date.txt')
        on(hosts, 'chcon --user unconfined_u /root/date.txt')
        $stderr.puts '<'*80

        retried = true
        retry
      end
    end

    it 'should generate auditd messages in the local secure log' do
      # restarting via a pair of 'puppet resource service auditd ensure=...'
      # operations returned a failure with 'stopped', so had to fall back on
      # command that actually works (even on el7)
      on(hosts, 'service auditd restart')

      begin
        on(non_syslog_servers, "egrep 'auditd\\[[0-9]+\\]: ' /var/log/secure")
      rescue => e
        skip "#{self.class.description} failed => #{e}"
      end
    end

    it 'should forward auditd logs' do
      begin
        verify_remote_log_messages(['auditd\\[[0-9]+\\]: '], 'secure.log', hosts, domain)
      rescue Beaker::Host::CommandFailure => e
        skip "#{self.class.description} failed => #{e}"
      end
    end

    # turn off audit forwarding for future tests, as it can be prolific
    it 'should disable audit log forwarding' do
      create_remote_file(master, default_yaml_filename, original_default_hieradata.to_yaml)
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

