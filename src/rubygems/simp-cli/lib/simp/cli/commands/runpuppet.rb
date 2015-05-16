module Simp::Cli::Commands; end

class Simp::Cli::Commands::Runpuppet < Simp::Cli
  require 'fileutils'

  @conf_dir = File.expand_path('~/.simp')
  @host_file = "#{@conf_dir}/hosts"
  @gen_host_list = true
  @max_parallel = 10
  @timeout = -1

  @opt_parser = OptionParser.new do |opts|
    opts.banner = "\n === The SIMP RunPuppet Tool ==="
    opts.separator ""
    opts.separator "The SIMP RunPuppet Tool allows you to run the Puppet agent on a list of hosts."
    opts.separator ""
    opts.separator "Some requirements to use the tool:"
    opts.separator " * the user must have SSH access to all of the list hosts"
    opts.separator " * the user cannot be root"
    opts.separator " * each target host must be able to run, with sudo, the following commands:"
    opts.separator "    - /usr/sbin/puppetd"
    opts.separator "    - /usr/sbin/puppetca"
    opts.separator ""
    opts.separator "OPTIONS:\n"

    opts.on("-H", "--hosts FILE", "FILE containing a list of hosts that Puppet should be run on") do |file|
      @host_file = file
      @gen_host_list = false
    end

    opts.on("-p", "--par NUM", "Maximum number of parallel threads. Defaults to 10.") do |num|
      @max_parallel = num
    end

    opts.on("-t", "--timeout SEC", "Set timeout to SEC seconds. Defaults to -1 (no timeout).",
      "\033[1mWARNING\033[0m: If your Puppet run takes more than SEC seconds, very bad things can happen!",
      "(i.e. your Puppet run will be killed)") do |sec|
      @timeout = sec
    end

    opts.on("-h", "--help", "Print this message") do
      puts opts
      exit 0
    end
  end

  def self.run(args = Array.new)
    super

    raise Simp::Runpuppet::Error.new("SIMP RunPuppet cannot be run as 'root'.") if Process.uid == 0

    host_list = Array.new
    if @gen_host_list
      host_list = %x{cd /;sudo /usr/sbin/puppetca --list --all}.split("\n").map do |host|
        host.split(/\(.*\)/).first.split(/\s+/).last.delete('"')
      end
    else
      File.open(@host_file).each_line do |line|
        host_list << line.chomp
      end
    end
    host_list.compact!

    system("echo '#{ "Please review the lists of hosts to run puppet on:\n - #{host_list.join("\n - ")}" }' | less -F")

    if Utils.yes_or_no("Run Puppet on all of the listed hosts?", false)
      host_errors = Array.new
      if @gen_host_list
        File.open(@host_file, 'w') do
          host_list.each { |host| file.puts host }
        end
      end

      puts "This may take some time..."
      %x{pssh -f -t #{@timeout} -p #{@max_parallel} -h #{@host_file} -OStrictHostKeyChecking=no "cd /; sudo /usr/sbin/puppetd --test"}.each_line do |line|
        puts line
        if line =~ /\[\d+\].*\[FAILURE\]\s([A-Za-z0-9\-\.]+).*/
          host_errors << $1
        end
      end

      if host_errors.empty?
        puts "Successfully ran Puppet for the #{host_list.size} hosts listed in #{@host_file}."
      else
        timestamp = Time.new.strftime("%Y%m%d%H%M")
        filepath = File.expand_path("#{@conf_dir}/pssh_error#{timestamp}")
        FileUtils.mkpath(File.dirname(filepath))
        File.open(filepath, 'w') do file
          host_errors.each { |err| file.puts err }
        end
        raise "Errors while running Puppet, outputting list of hosts with errors to #{@conf_dir}/pssh_error#{timestamp}"
      end
    end
  end
end
