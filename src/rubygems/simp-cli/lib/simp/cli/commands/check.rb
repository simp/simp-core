module Simp::Cli::Commands; end

class Simp::Cli::Commands::Check < Simp::Cli
  @opt_parser = OptionParser.new do |opts|
    opts.banner = "*Options*"

    opts.on("-A", "--all", "Run all checks, equivalent to -nkl") do
      @check_network = true
      @check_keys = true
      @check_ldap = true
    end

    opts.on("-p", "--pre", "Run checks that should pass before first run, equivalent to -nk") do
      @check_network = true
      @check_keys = true
    end

    opts.on("-n", "--network", "Check network items") do
      @check_network = true
    end

    opts.on("-k", "--keys", "Check that keys have been generated for the host") do
      @check_keys = true
    end

    opts.on("-l", "--ldap", "Check validity of ldap passwords") do
      @check_ldap = true
    end

    opts.on("-v", "--verbose", "Run verbosely") do
      @verbose = true
    end

    opts.on("-r", "--report FILE", "Create a report in FILE. NOTE: if FILE exists, it will be overwritten!") do |file|
      @report_file = file
    end

    opts.on("-h", "--help", "Print this message") do
      puts opts
      exit
    end
  end

  def self.run(args)
    raise "simp check Requires Arguments" if args.empty?

    super

    @version = Simp.version

    report = []

    system('clear')

    if @check_network
      report.push "\n***Starting Network Check***\n"

      hostname = `hostname`.gsub!(/\s+/, '')

      begin
        network_hostname = `grep HOSTNAME /etc/sysconfig/network`.strip.match(/HOSTNAME\s*=\s*([^ ]*)/)[1]
      rescue
        report.push "ERROR: No hostname in /etc/sysconfig/network"
      end

      if hostname == network_hostname
        report.push "Hostname matches hostname in /etc/sysconfig/network"
      else
        report.push "ERROR: Hostname does not match hostname in /etc/sysconfig/network"
      end

      if `grep ^127.0.0.1 /etc/hosts`.split("\n").any? { |line| line =~ /localhost.localdomain[\s+\z]/ and line =~ /localhost[\s+\z]/ }
        report.push "Found valid entry for 127.0.0.1 in /etc/hosts"
      else
        report.push "ERROR: Did not find valid entry for 127.0.0.1 in /etc/hosts"
      end

      if `grep ^::1 /etc/hosts`.split("\n").any? { |line| line =~ /localhost6\.localdomain6(\s+|$)/ and line =~ /localhost6(\s+|$)/ }
        report.push "Found valid entry for ::1 in /etc/hosts"
      else
        report.push "ERROR: Did not find valid entry for ::1 in /etc/hosts"
      end
    end

    if @check_keys
      report.push "\n***Starting Keys Check***\n"

      key_count = 0
      valid_key_count = 0

      Dir.foreach("/etc/puppet/keydist") do |host|
        if (host !~ /\A\.+\z/) and (host !~ /\Acacerts\z/) and File::directory?("/etc/puppet/keydist/#{host}")
          Dir.foreach("/etc/puppet/keydist/#{host}") do |key|
            if key =~ /\.pem\z/ or key =~ /\.pub\z/
              key_count += 1

              if `openssl verify -CApath /etc/puppet/keydist/cacerts /etc/puppet/keydist/#{host}/#{key}`.strip =~ /\s+OK\z/
                valid_key_count += 1
                report.push "Key /etc/puppet/keydist/#{host}/#{key} validated\n"
              else
                report.push "ERROR: Key /etc/puppet/keydist/#{host}/#{key} did not validate\n"
              end
            end
          end
        end
      end

      if key_count == 0
        report.push "ERROR: No keys found (recursively) in /etc/puppet/keydist\n"
      else
        report.push "#{valid_key_count}/#{key_count} keys validated\n"
      end
    end

    if @check_ldap
      report.push "\n***Starting Ldap Check***\n"

      binddn = ""
      bindpw = ""
      host = ""
      base = ""

      ldap_conf = '/etc/ldap.conf'
      ldap_conf = '/etc/pam_ldap.conf' unless File.file?(ldap_conf)

      File.open(ldap_conf).each_line do |line|
        if (line =~ /\Abinddn\s+/) != nil
          binddn = line.gsub(/\Abinddn\s+/, "").chomp
        elsif (line =~ /\Abindpw\s+/) != nil
          bindpw = line.gsub(/\Abindpw\s+/, "").chomp
        elsif (line =~ /\Auri\s+/) != nil
          host = line.gsub(/\Auri\s+/, "").chomp
        elsif (line =~ /\Anss_base_passwd\s+/) != nil
          base = line.gsub(/\Anss_base_passwd\s+/, "").chomp.gsub(/\?.*/, "")
        end
      end

      exit_code = `ldapsearch -Z -LLLL -D "#{binddn}" -x -w "#{bindpw}" -H "#{host}" -b "#{base}" -s one uid sshPublidKey`.to_i

      if exit_code == 0
        report.push "Ldap appears to be working\n"
      else
        report.push "ERROR: Ldap does not appear to be working; ldapsearch exited with code #{exit_code}\n"
      end
    end

    report = report.select { |line| line =~ /\A(\*\*\*|WARNING|ERROR)/ } unless @verbose

    report = report.join("\n")

    unless @report_file.nil?
      begin
        f = File.open(File.expand_path(@report_file), 'w')
        f.puts report
        f.close
      rescue
        raise "An error occurred while writing the report:#{$!}"
      end
    end

    puts report
  end
end
