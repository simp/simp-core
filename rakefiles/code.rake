#!/usr/bin/rake -T

require 'simp/rake'
include Simp::Rake

namespace :code do

  desc "Show some basic stats. Uses git to figure out what has changed.
 * :since - Do not include any stats before this date.
 * :until - Do not include any stats after this date."
  task :stats,[:since,:until] do |t,args|
    cur_branch = %x{git rev-parse --abbrev-ref HEAD}.chomp

    if cur_branch.empty? then
      fail "Error: Could not find branch ID!"
    end

    changed = 0
    new = 0
    removed = 0

    cmd = "git log --shortstat --reverse --pretty=oneline"

    if args.since then
      cmd = cmd + " --since=#{args.since}"
    end
    if args.until then
      cmd = cmd + " --until=#{args.until}"
    end

    %x{#{cmd}}.each_line do |line|
      if encode_line(line) =~ /(\d+) files changed, (\d+) insertions\(\+\), (\d+) del.*/ then
        changed = changed + $1.to_i
        new = new + $2.to_i
        removed = removed + $3.to_i
      end
    end

    cmd = "git submodule foreach git log --shortstat --reverse --pretty=oneline"

    if args.since then
      cmd = cmd + " --since=#{args.since}"
    end
    if args.until then
      cmd = cmd + " --until=#{args.until}"
    end

    %x{#{cmd}}.each_line do |line|
      if encode_line(line) =~ /(\d+) files changed, (\d+) insertions\(\+\), (\d+) del.*/ then
        changed = changed + $1.to_i
        new = new + $2.to_i
        removed = removed + $3.to_i
      end
    end

    puts "Code Stats for #{cur_branch}:"
    printf "  Files Changed: %6d\n", changed
    printf "  New Lines:     %6d\n", new
    printf "  Removed Lines: %6d\n", removed
  end # End of :stats task.

  desc "Show line count. Prints a report of the lines of code in the source.
 * :show_unknown - Flag for displaying any file extensions not expected."
  task :count,[:show_unknown] do |t,args|
    require 'find'

    loc = Hash.new
    loc["rake"] = 0
    loc["pp"] = 0
    loc["rb"] = 0
    loc["erb"] = 0
    loc["sh"] = 0
    loc["csh"] = 0
    loc["html"] = 0
    loc["spec"] = 0
    loc["other"] = 0

    File.open("#{SRC_DIR}/../Rakefile","r").each do |line|
      if encode_line(line) !~ /^\s*$/ then
        loc["rake"] = loc["rake"] + 1
      end
    end.close

    other_ext = Array.new

    Find.find(SRC_DIR) do |path|
        if (
          ( File.basename(path)[0] == ?. ) or
          ( path =~ /src\/rsync/ ) or
          ( path[-3..-1] =~ /\.gz|pem|pub/ ) or
          ( path =~ /developers_guide\/rdoc/ )
        ) then
          Find.prune
        else
          next if FileTest.symlink?(path) or FileTest.directory?(path)
        end

      ext = File.extname(path)[1..-1]
      if not ext then ext = 'none' end
      if not loc[ext] then
        other_ext.push(ext) if not other_ext.include?(ext)
        ext = 'other'
      end

      File.open(path,'r').each do |line|
        if encode_line(line) !~ /^\s*$/ then
          loc[ext] = loc[ext] + 1
        end
      end
    end

    puts "Code Count Report:"
    printf "  %-6s %6s\n", "Ext", "Count"
    puts "  " + ("-" * 13)

    total_loc = 0
    loc.sort.each do |key,val|
      printf "  %-6s %6d\n", key, val
      total_loc = total_loc + val
    end

    puts "  " + ("-" * 13)
    printf "  %-6s %6d\n", "Total", "#{total_loc}"
    puts
    puts "Unknown Extension Count: #{other_ext.length}"

    if args.show_unknown then
      puts "Unknown Extensions:"
      other_ext.sort.each do |ext|
        puts "  #{ext}"
      end
    end
  end # End of :count task.

end # End of :code namespace.
