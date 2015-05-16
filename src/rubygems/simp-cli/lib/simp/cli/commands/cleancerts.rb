module Simp::Cli::Commands; end

class Simp::Cli::Commands::Cleancerts < Simp::Cli
  @conf_dif = File.expand_path('~/.simp')
  @host_file = "#{@conf_dir}/hosts"
  @gen_host_list = true
  @host_list = Array.new
  @host_errors = Array.new

  @opt_parser = OptionParser.new do |opts|
    opts.banner = "\n === The SIMP CleanCerts Tool ==="
    opts.separator ""
    opts.separator "The SIMP CleanCerts Tool revokes and removes the Puppet certificates from a"
    opts.separator "list of hosts."
    opts.separator ""
    opts.separator "Some requirements to use this tool:"
    opts.separator " * the user must have SSH access to all of the list hosts"
    opts.separator " * the user cannot be root"
    opts.separator " * each target host must be able to run, with sudo, the following commands:"
    opts.separator "    - /usr/sbin/puppetd"
    opts.separator "    - /usr/sbin/puppetca"
    opts.separator "    - /bin/rm -rf /var/lib/puppet/ssl"
    opts.separator ""
    opts.separator "This tool will not clean the certificates for the hostname of the current box"
    opts.separator "or the Puppet server listed in puppet.conf."
    opts.separator ""
    opts.separator "OPTIONS:\n"

    opts.on("-H", "--hosts FILE", "FILE containing a list of hosts to clean.") do |file|
      @host_file = file
      @gen_host_list = false
    end

    opts.on("-h", "--help", "Print this message") do
      puts opts
      exit 0
    end
  end


  def self.clean_certs

    success
  end

  def self.run(args = Array.new)
    File.exists?('/usr/sbin/puppetd') && File.exists?('/usr/sbin/puppetca')

    raise "SIMP CleanCerts cannot be run as 'root'." if Process.uid == 0

    @host_list = Array.new
    if @gen_host_list
      @host_list = %x{cd /;sudo /usr/sbin/puppetca --list --all}.split("\n").map { |host| host.split(/\(.*\)/).first.split(/\s+/).last }
    else
      File.open(@host_file).each_line do |line|
        @host_list << line.chomp
      end
    end
    @host_list.compact!

    if @host_list.size == 0
      puts "No known hosts to clean!"
      exit 0
    end

    system("echo 'Please review the list of hosts to clean certificates on:\n - #{@host_list.join("\n - ")}' | less -f")

    if Utils.yes_or_no("Clean certificates for all listed hosts?", false)
      if @gen_host_list
        file = File.open(@host_file, 'w')
        @host_list.each do |host|
          file.puts host
        end
        file.close
      end

      @host_list.each do |host|
        %{sudo /usr/sbin/puppetca --revoke #{host}}
        %{sudo /usr/sbin/puppetca --clean #{host}}
      end

      result = %x{pssh -f -h #{@host_file} -OStrictHostKeyChecking=no "sudo /bin/rm -rf /var/lib/puppet/ssl"}
      result.each_line do |line|
        if line =~ /.*\[FAILURE\]\s([A-Za-z0-9\-\.]+).*/
          success = false
          @host_errors << $1
        end
      end

      if @host_errors.empty?
        puts "Successfully cleaned certificates for the #{@host_list.size} hosts listed in #{@host_file.path}."
      else
        filename = "#{@conf_dir}/pssh_error#{Time.now.strftime("%Y%m%d%H%M")}"
        File.open(filename, 'w') do
          @host_errors.each { |err| file.puts err }
        end
        raise "Errors occured while cleaning certificates, outputting list of hosts with errors to #{filename}"
      end
    else
      if @gen_host_list
        puts "If you do not want to clean all certificates, you can place"
        puts "all hosts you want to clean in a newline-delimited file and"
        puts "use the '--hosts <hosts_file>' command line option."
      end

      puts "If you want to manually clean certificates on all boxes,"
      puts "follow the steps to clean certificates from the "
      puts "'\033[1mChanging Puppet Masters\033[21m' users guide."
      puts "Also look through the '\033[1mPerforming One Shot Operations\033[21m'"
      puts "users guide for guidance on doing this with PSSH.\n"
      puts "Users guides can be found using '\033[1msimp doc\033[21m'."
    end
  end
end
