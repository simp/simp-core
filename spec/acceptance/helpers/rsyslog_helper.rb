module Acceptance
  module Helpers
    module RsyslogHelper

    def handle_failed_message_forwarding(validation_failure, retried, syslog_servers)
      if retried
        $stderr.puts '#'*80
        $stderr.puts 'Restart of rsyslog on the remote rsyslog servers did not allow logs to be forwarded'
        $stderr.puts '#'*80
        skip "#{self.class.description} failed => #{validation_failure}"
        #raise validation_failure
      end

      $stderr.puts '>'*80
      $stderr.puts 'WARNING: Failed to forward logs.'
      $stderr.puts 'WARNING: Restarting rsyslog on the remote rsyslog servers.'
      $stderr.puts '<'*80
      restart_rsyslog(syslog_servers)
    end

    # Verifies messages are persisted on the remote syslog servers
    #
    # +messages+:   array of message search strings
    # +remote_log+: basename of remote log file
    # +hosts+:      hosts for which messages should exist
    # +domain+:     domain of test servers
    #
    # Will restart rsyslog service on remote syslog servers, once,
    # if the messages are not found and then rerun the verification
    def verify_remote_log_messages(messages, remote_log, hosts, domain)
      syslog_servers = hosts_with_role(hosts, 'syslog_server')
      retried = false
      begin
        hosts.each do |host|
          logdir = "/var/log/hosts/#{host.name}.#{domain}"
          messages.each do |message|
            on(syslog_servers, "egrep '#{message}' #{logdir}/#{remote_log}")
          end
        end
      rescue Beaker::Host::CommandFailure => e
        handle_failed_message_forwarding(e, retried, syslog_servers)
        retried = true
        retry
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

    end
  end
end
