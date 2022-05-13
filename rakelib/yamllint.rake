require 'find'

namespace :check do
  namespace :syntax do
    desc <<~DESC
      Check syntax of yaml files

      Checks .yaml/.yml files in the top directory, and under build/ & .github/
    DESC
    task :yaml do
      bad = []
      seen = []
      Rake::FileList.new(['{build/**/,.github/**/}*.{yaml,yml}']).each do |f|
        begin
          seen << f
          YAML.safe_load(File.read(f), permitted_classes: [Symbol])
        rescue Exception => e
          STDERR.puts "\n", "-- #{f}", "#{e.class}: #{e.message}"
          bad << f
        end
      end

      puts "\nScanned #{seen.size} files, found #{bad.size} errors\n"
      unless bad.empty?
        STDERR.puts("ERROR: #{bad.size} YAML files failed loading during syntax check")
        exit 1
      end
    end
  end
end
