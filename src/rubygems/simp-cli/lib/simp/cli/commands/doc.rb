module Simp::Cli::Commands; end

class Simp::Cli::Commands::Doc < Simp::Cli
  def self.run(args = Array.new)
    raise "Package 'simp-doc' is not installed, cannot continue" unless system("rpm -q --quiet simp-doc")
    pupdoc = "/usr/share/doc/simp-#{ %x{rpm -q simp-doc | cut -f3 -d'-'}.chomp }/html/index.html"
    raise "Could not find the SIMP documentation. Please ensure that you can access '#{pupdoc}'." unless File.exists?(pupdoc)
    exec("links #{pupdoc}")
  end

  def self.help
    puts "Show SIMP documentation in elinks"
  end
end
