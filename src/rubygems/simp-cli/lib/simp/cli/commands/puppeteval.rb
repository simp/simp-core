module Simp::Cli::Commands; end

class Simp::Cli::Commands::Puppeteval < Simp::Cli
  require 'facter'

  def self.help
    puts "This tool gathers metric information for a Puppet run that it will run."
  end

  def self.run(args = Array.new)

    data = {
      :facter => Facter.to_hash,
      :puppet_tags => ['--test','--evaltrace','--summarize'],
      :cpuinfo => [],
      :meminfo => {},
      :summarize => {},
      :evaltrace => []
    }

    proc_hash = Hash.new
    File.open('/proc/cpuinfo', 'r').each do |line|
      if line =~ /(.*)\s*: (.*)/
        proc_hash[$1.strip] = $2
      elsif line =~ /\A\s*\z/
        data[:cpuinfo] << proc_hash
        proc_hash = Hash.new
      end
    end
    data[:cpuinfo] << proc_hash if !proc_hash.empty?

    File.open('/proc/meminfo', 'r').each do |line|
      if line =~ /(.*):\s*([0-9]*( kB)?)/
        data[:meminfo][$1] = $2
      end
    end

    # Wait for puppet to not be currently running...
    puppet_running = true
    found_puppet = false
    while puppet_running do
      ps_output = %x{/bin/ps aux | /bin/grep puppet}.each_line do |l|
        if l =~ /\/usr\/s?bin\/puppet(d|\s+agent)/
          sleep(2)
          found_puppet = true
          break
        end
      end
      puppet_running = found_puppet
      found_puppet = false
    end

    PTY.spawn("/usr/bin/puppet agent --test --evaltrace  --summarize 2> /dev/null") do |read, write, pid|
      begin
        at_summary = false
        read.each do |line|
          if at_summary
            if line =~ /\A(\S+.*):/
              summary_hash = $1
              data[:summarize][summary_hash] = Hash.new
            elsif line =~ /\s+(\S+.*): ([0-9\.]*)/
              data[:summarize][summary_hash][$1] = $2
            end
          end
          if line =~ /info: (.*): Evaluated in (.*) seconds/
            data[:evaltrace] << { :resource => $1, :time => $2 }
          elsif line =~ /notice: Finished catalog run in ([0-9\.]*) seconds/
            data[:evaltrace] << { :resource => "catalog run", :time => $1 }
            at_summary = true
          end
          puts line
        end
      rescue Errno::EIO
      end
    end

    FileUtils.mkdir_p("/var/tmp/simp_mit/")
    File.open( "/var/tmp/simp_mit/simp_#{Time.now.to_i}_#{Socket.gethostname}.yml", 'w') do |file|
      YAML::dump(data, file)
    end
  end
end
