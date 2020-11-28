require 'spec_helper_integration'

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

syslog_servers = hosts_with_role(hosts, 'syslog_server')
non_syslog_servers = hosts - syslog_servers
master      = only_host_with_role(hosts, 'master')
# facts gathered here are executed when the file first loads and
# use the factor gem temporarily installed into system ruby
domain = fact_on(master, 'domain')

describe 'Validation of rsyslog forwarding' do
  options = {
    :domain      => domain,
    :scenario    => 'simp_lite',
    :master      => master
  }

  include_examples 'SIMP Rsyslog Tests', syslog_servers, non_syslog_servers, options
end

