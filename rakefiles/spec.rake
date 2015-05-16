#!/usr/bin/rake -T
namespace :spec do

  desc "Bump spec files. Bump all spec files' release numbers up by one.
 * :list - Flag to just print the current version numbers."
  task :bump,[:list] do |t,args|
    (
      Dir.glob("#{SPEC_DIR}/*.spec") +
      Dir.glob("#{SRC_DIR}/puppet/modules/*/pkg/pupmod-*.spec")
    ).each do |spec|
      if args.list then
        File.open(spec).each do |line|
          if line =~ /Name:\s*(.*)/ then
            print $1.chomp + ' -> '
            next
          elsif line =~ /Version:\s*(.*)/ then
            print $1.chomp + '-'
            next
          elsif line =~ /Release:\s*(.*)/ then
            puts $1.chomp
            next
          end
        end
      else
        tmpfile = File.open("#{SPEC_DIR}/~#{File.basename(spec)}","w+")
        File.open(spec).each do |line|
          if line =~ /Release:/ then
            tmpfile.puts "Release: #{line.split(/\s/)[1].to_i + 1}"
          else
            tmpfile.puts line.chomp
          end
        end
        tmpfile.close
        mv(tmpfile.path,spec)
      end
    end
  end # End of bump task
end
