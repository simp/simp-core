#!/usr/bin/rake -T

require 'simp/rake/pupmod/helpers'

Simp::Rake::Beaker.new(File.dirname(__FILE__))

begin
  require 'simp/rake/build/helpers'
  BASEDIR    = File.dirname(__FILE__)
  Simp::Rake::Build::Helpers.new( BASEDIR )
rescue LoadError => e
  warn "WARNING: #{e.message}"
end


task :default do
  help
end

task :build_mco_plugins do
  cmd = ['mco','plugin','package']
  cmd += ['--format aiomodulepackage','--vendor choria','--config src/mcollective/plugins/build.cfg']

  Dir.glob('src/mcollective/plugins/**').each do |plugin|
    cmd += plugin
    require 'pry';binding.pry
    puts run.join(' ')
    `#{run.join(' ')}`
  end

end