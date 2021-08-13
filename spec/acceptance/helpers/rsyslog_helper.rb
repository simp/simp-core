module Acceptance
  module Helpers
    module RsyslogHelper

      # Fail or skip the current test example, when a forwarded log message
      # cannot be found on the rsyslog server
      #
      # Forwarded messages are often missing because they (are presumed to be) in
      # the rsyslog cache, and there is no mechanism to force the rsyslog server
      # to flush its cache. So, by default skipping of these tests is enabled.
      #
      # Error handling behavior can also be globally set via
      # SIMP_CORE_SKIP_FORWARD_LOG_FAILURES.
      #
      def handle_forward_log_failures(test_name, err_msg, skip_forward_failures = true)
        failure_msg = "#{test_name} failed => #{err_msg}"

        skip_failures = skip_forward_failures
        if ENV.key?('SIMP_CORE_SKIP_FORWARD_LOG_FAILURES')
          # use global override
          skip_failures = (ENV['SIMP_CORE_SKIP_FORWARD_LOG_FAILURES']=='yes')
        end

        if skip_failures
          skip failure_msg
        else
          raise failure_msg
        end
      end

      # Fail or skip the current test example, when a local log message
      # cannot be found on the rsyslog server
      #
      # We expect local log messages to always be present, so by default, skipping
      # of these messages is disabled.
      #
      # Error handling behavior can also be globally set via
      # SIMP_CORE_SKIP_LOCAL_LOG_FAILURES.
      #
      def handle_local_log_failures(test_name, err_msg, skip_local_failures = false)
        failure_msg = "#{test_name} failed => #{err_msg}"

        skip_failures = skip_local_failures
        if ENV.key?('SIMP_CORE_SKIP_LOCAL_LOG_FAILURES')
          # use global override
          skip_failures = (ENV['SIMP_CORE_SKIP_LOCAL_LOG_FAILURES']=='yes')
        end

        if skip_failures
          skip failure_msg
        else
          raise failure_msg
        end
      end


      # @return whether all log messages are found in the local logs for all
      #   logging hosts
      #
      # @param messages  Message or Array of messages to verify
      # @param logfile  Fully qualified path to file in which to find log messages
      # @param logging_hosts  Host or Array of Hosts to be checked for the message
      # @param options  `retry_on` options to apply; :max_retries defaults to 1
      #   and :retry_interval defaults to 2
      #
      def verify_local_log_messages(messages, logfile, logging_hosts, options = {})
        opts = { :max_retries => 1, :retry_interval => 2 }.merge(options)
        failures = []
        Array(messages).each do |message|
          Array(logging_hosts).each do |host|
            begin
              retry_on(host, "date; egrep '#{message}' #{logfile}", opts)
            rescue RuntimeError => e
              $stderr.puts "ERROR LOCAL LOGGING: #{e}"
              on(host, "tail #{logfile}", :accept_all_exit_codes => true)
              failures << e
            end
          end
        end

        failures.empty?
      end

      # @return whether all log messages are found in the forwarded logs for all
      #   logging hosts on all syslog servers
      #
      # @param messages  Message or Array of messages to verify
      # @param remote_log  Basename of remote log file in which to find log messages
      # @param logging_host Hosts from which messages should have been forwarded
      #    into /var/log/hosts/<host fqdn>/
      #
      # @param syslog_servers Hosts on which the forwarded logs should reside
      # @param domain Domain to be added to each hosts's name, if missing
      # @param options Retry options which control `retry_on` behavior and whether
      #   to restart rsyslog upon forwarding failure
      #
      #   * :max_retries and :retry_interval are passed directly into `retry_on`
      #     - :max_retries defaults to 5
      #     - :retry_interval defaults to 2
      #   * :restart_on_failure is Boolean controlling whether the rsyslog server
      #     should be restarted and the log verification tried one additional
      #     time, when the log message could not be found on the rsyslog server
      #     - Defaults to false, as restarting the rsyslog server doesn't reliably
      #       solve the problem
      #     - Can be globally set with SIMP_CORE_RESTART_FORWARD_LOG_FAILURES
      #       environment variable
      #
      def verify_remote_log_messages(messages, remote_log, logging_hosts, syslog_servers, domain, options = {})
        # parse options
        retry_on_opts = { :max_retries => 5, :retry_interval => 2 }
        retry_on_opts[:max_retries] = options[:max_retries] if options.key?(:max_retries)
        retry_on_opts[:retry_interval] = options[:retry_interval] if options.key?(:retry_interval)

        # Restarting the rsyslog server upon search failure has been demonstrated
        # to **NOT** reliably help in an automated test (perhaps timing?). So, we
        # don't enable this by default anymore.
        restart_on_failure = options.key?(:restart_on_failure) ? options[:restart_on_failure] : false
        if ENV.key?('SIMP_CORE_RESTART_FORWARD_LOG_FAILURES')
          # use global override
          restart_on_failure = (ENV['SIMP_CORE_RESTART_FORWARD_LOG_FAILURES']=='yes')
        end

        failures = []
        Array(logging_hosts).each do |host|
          # nodeset may specify the host with the domain
          host_fqdn = host.name.include?(domain) ? host.name : "#{host.name}.#{domain}"
          logdir = "/var/log/hosts/#{host_fqdn}"
          Array(messages).each do |message|
            Array(syslog_servers).each do |syslog_server|
              retried_after_restart = false
              begin
                retry_on(syslog_server, "egrep '#{message}' #{logdir}/#{remote_log}", retry_on_opts)
              rescue RuntimeError => e
                if restart_on_failure && !retried_after_restart
                  retried_after_restart = true
                  $stderr.puts '>'*80
                  $stderr.puts "WARNING: Restarting rsyslog on #{syslog_server} and then re-checking for message."
                  $stderr.puts '<'*80
                  restart_rsyslog(syslog_server)
                  retry
                else
                  $stderr.puts "ERROR REMOTE LOGGING: #{e}"
                  on(host, "tail #{logdir}/#{remote_log}", :accept_all_exit_codes => true)
                  failures << e
                end
              end
            end
          end
        end

        failures.empty?
      end

      def restart_rsyslog(hosts)
        cmds = [
          'puppet resource service rsyslog ensure=stopped',
          'puppet resource service rsyslog ensure=running'
        ]
        on(Array(hosts), "#{cmds.join('; ')}")

        # give rsyslogd time to really start up
        sleep(5)
      end
    end
  end
end
