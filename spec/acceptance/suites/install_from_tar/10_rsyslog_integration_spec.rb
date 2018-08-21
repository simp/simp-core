require 'spec_helper_tar'

test_name 'rsyslog integration'

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
# 2) There are numerous inconsistencies in the names of local and
#    remote logs, and into which local/remote log messages are written.
#    (See SIMP-3480).  The tests are written for the *current* rsyslog
#    configuration, not the *desired* rsyslog configuration.
# 3) In most cases, messages from a syslog server, itself, that would
#    have been forwarded if the host was not a syslog server, are written
#    to /var/log/hosts/<syslog server fqdn>, instead of the local file
#    to which other hosts write their messages. This provides consistency
#    for the sysadmins examining host logs on the syslog server.
# 4) More tests need to be done...Notes can be found in a
#    commented out block at the end of the file.
#
describe 'Validation of rsyslog forwarding' do

  syslog_servers = hosts_with_role(hosts, 'syslog_server')
  non_syslog_servers = hosts - syslog_servers

  domain         = fact_on(master, 'domain')
  master_fqdn    = fact_on(master, 'fqdn')

  # messages       = array of message search strings
  # remote_log     = basename of remote log file
  # hosts          = hosts for which messages should exist
  # domain         = domain of test servers
  def verify_remote_log_messages(messages, remote_log, hosts, domain)
    syslog_servers = hosts_with_role(hosts, 'syslog_server')

    hosts.each do |host|
      logdir = "/var/log/hosts/#{host.name}.#{domain}"
      messages.each do |message|
        on(syslog_servers, "egrep '#{message}' #{logdir}/#{remote_log}")
      end
    end
  end

  def restart_rsyslog(hosts)
    cmds = [
      'puppet resource service rsyslog ensure=stopped',
      'puppet resource service rsyslog ensure=running'
    ]
    on(hosts, "#{cmds.join('; ')}")

    # give rsyslogd time to really start up
    sleep(5)
  end

  let(:files_dir) { 'spec/acceptance/common_files' }

  let(:default_yaml_filename) {
    '/etc/puppetlabs/code/environments/simp/hieradata/default.yaml'
  }

  let(:site_module_path) {
    '/etc/puppetlabs/code/environments/simp/modules/site'
  }

  let(:default_hieradata) {
    # hieradata that allows beaker operations access
    beaker_hiera = YAML.load(File.read("#{files_dir}/beaker_hiera.yaml"))

    hiera        = beaker_hiera.merge( {
      'simp::rsync_stunnel'         => master_fqdn,
      'rsyslog::enable_tls_logging' => true,
      'simp_rsyslog::forward_logs'  => true,

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
      dest = "#{site_module_path}/manifests/local_users.pp"
      scp_to(master, "#{files_dir}/site/manifests/local_users.pp", dest)
      on(master, "chown root:puppet #{dest}")
      on(master, "chmod 0640 #{dest}")

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
      verify_remote_log_messages(['Applied catalog in'], 'puppet_agent.log', hosts, domain)
      verify_remote_log_messages(['Could not find class ::oops '], 'puppet_agent_error.log',
        hosts, domain)
    end

    it 'should forward puppetserver logs' do
      logdir = "/var/log/hosts/#{master.name}.#{domain}"
      on(syslog_servers, "ls #{logdir}/puppetserver.log")
      on(syslog_servers, "grep 'Could not find class ::oops ' #{logdir}/puppetserver_error.log")
    end

    it 'should generate systemd log messages in the local secure log' do
      hosts.each do |host|
        facts = JSON.load(on(host, 'puppet facts').stdout)
        if facts['values']['systemd']
          on(host, 'systemctl restart haveged.service')
          unless host.host_hash[:roles].include?('syslog_server')
            on(host, "grep 'systemd: Stopping Entropy Daemon based on the HAVEGE' /var/log/secure")
            on(host, "grep 'systemd: Starting Entropy Daemon based on the HAVEGE' /var/log/secure")
          end
        else
          puts "Skipping host #{host.name}, which does not use systemd"
        end
      end
    end

    it 'should forward systemd logs' do
      hosts.each do |host|
        facts = JSON.load(on(host, 'puppet facts').stdout)
        if facts['values']['systemd']
          logdir = "/var/log/hosts/#{host.name}.#{domain}"
          on(syslog_servers, "grep 'systemd: Stopping Entropy Daemon based on the HAVEGE' #{logdir}/secure.log")
          on(syslog_servers, "grep 'systemd: Starting Entropy Daemon based on the HAVEGE' #{logdir}/secure.log")
        else
          puts "Skipping host #{host.name}, which does not use systemd"
        end
      end
    end

    it 'should generate a local yum log' do
      hosts.each do |host|
        host.install_package('expect')
        unless host.host_hash[:roles].include?('syslog_server')
          on(host, "grep 'Installed: expect' /var/log/yum.log")
        end
      end
    end

    it 'should forward yum logs' do
      verify_remote_log_messages(['Installed: expect'], 'secure.log', hosts, domain)
    end

    it 'should generate a local cron log' do
      # retry_on() is supposed to work on Hosts array, but doesn't
      non_syslog_servers.each do |host|
        retry_on(host,
          "egrep 'CROND.*: .root. CMD ./usr/local/sbin/dynamic_swappiness.rb' /var/log/cron",
          {:retry_interval =>5, :max_retries => 15}
        )
      end
    end

    it 'should forward cron logs' do
      verify_remote_log_messages(['CROND.*: .root. CMD ./usr/local/sbin/dynamic_swappiness.rb'],
        'cron.log', hosts, domain)
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
      verify_remote_log_messages(['found differences between database and filesystem'],
        'aide.log', hosts, domain)
    end

    it 'should generate a local iptables.log' do
      hosts.each { |host| host.install_package('wget') }

      # None of the servers are set up as web servers, yet, so attempting
      # web access to these servers should result in iptables dropped
      # packet logs
      non_syslog_servers.each do |host|
        cmd = "wget --tries=1 --timeout=1 https://#{host.name}.#{domain}/somefile"
        on(syslog_servers, cmd, :accept_all_exit_codes => true)
      end

      syslog_servers.each do |host|
        cmd = "wget --tries=1 --timeout=1 https://#{host.name}.#{domain}/somefile"
        on(non_syslog_servers.first, cmd, :accept_all_exit_codes => true)
      end

      on(non_syslog_servers, "grep 'kernel: IPT:' /var/log/iptables.log")
    end

    it 'should forward iptables dropped packet logs' do
      verify_remote_log_messages(['kernel: IPT:'], 'iptables.log', hosts, domain)
    end

    it 'should generate a local sudosh.log' do
      # This test will use an expect script that ssh's to a host as a
      # local user configured with no password sudosh privileges, runs
      # 'sudo sudosh', and then executes a root-level command.
      # Before the user can login, we need to set the user's password
      on(hosts, "echo '#{test_password}' | passwd localadmin --stdin")
      scp_to(master, "#{files_dir}/ssh_sudo_sudosh_script", '/usr/local/bin/ssh_sudo_sudosh_script')
      on(master, "chmod +x /usr/local/bin/ssh_sudo_sudosh_script")
      hosts.each do |host|
        base_cmd ="/usr/local/bin/ssh_sudo_sudosh_script localadmin #{host.name} #{test_password}"

        # FIXME: Workaround for SIMP-5082
        cmd = adjust_ssh_ciphers_for_expect_script(base_cmd, master, host)
        on(master, cmd)

        unless host.host_hash[:roles].include?('syslog_server')
          on(host, "grep 'sudosh: starting session for localadmin as root' /var/log/sudosh.log")
          on(host, "grep 'sudosh: stopping session for localadmin as root' /var/log/sudosh.log")
        end
      end
    end

    it 'should forward sudosh logs' do
      verify_remote_log_messages(
        [ 'sudosh: starting session for localadmin as root',
          'sudosh: stopping session for localadmin as root'
        ],
        'sudosh.log', hosts, domain)
    end

    it 'should generate sudo messages in the local secure log' do
      # The previous test should have generated sudo logs about 'sudo sudosh'
      on(non_syslog_servers, "grep 'sudo: localadmin : .* COMMAND=.*/sudosh' /var/log/secure")
    end

    it 'should forward sudo logs' do
      verify_remote_log_messages(
        ['sudo: localadmin : .* COMMAND=.*/sudosh'], 'secure.log',
        hosts, domain)
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
          raise e
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

      on(non_syslog_servers, "egrep 'auditd\\[[0-9]+\\]: ' /var/log/secure")
    end

    it 'should forward auditd logs' do
      verify_remote_log_messages(['auditd\\[[0-9]+\\]: '], 'secure.log', hosts, domain)
    end

    # turn off audit forwarding for future tests, as it can be prolific
    it 'should disable audit log forwarding' do
      create_remote_file(master, default_yaml_filename, default_hieradata.to_yaml)
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
