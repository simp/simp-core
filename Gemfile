# ------------------------------------------------------------------------------
#         NOTICE: **This file is maintained with puppetsync**
#
# This file is automatically updated as part of a puppet module baseline.
# The next baseline sync will overwrite any local changes made to this file.
# ------------------------------------------------------------------------------
gem_sources = ENV.fetch('GEM_SERVERS', 'https://rubygems.org').split(%r{[, ]+})

ENV['PDK_DISABLE_ANALYTICS'] ||= 'true'

gem_sources.each { |gem_source| source gem_source }

group :test do
  puppet_version = ENV.fetch('PUPPET_VERSION', ['>= 7', '< 9'])
  major_puppet_version = Array(puppet_version).first.scan(%r{(\d+)(?:\.|\Z)}).flatten.first.to_i
  gem 'hiera-puppet-helper'
  gem 'metadata-json-lint'
  gem 'naturally'
  gem 'pathspec', '~> 0.2' if Gem::Requirement.create('< 2.6').satisfied_by?(Gem::Version.new(RUBY_VERSION.dup))
  gem('pdk', ENV.fetch('PDK_VERSION', ['>= 2.0', '< 4.0']), require: false) if major_puppet_version > 5
  gem 'puppet', puppet_version
  gem 'puppetlabs_spec_helper'
  gem 'puppet-lint-trailing_comma-check', require: false
  gem 'puppet-strings'
  gem 'rake'
  gem 'rspec'
  gem 'rspec-puppet'
  gem 'simp-rake-helpers', ENV.fetch('SIMP_RAKE_HELPERS_VERSION', ['>= 5.21.0', '< 6'])
  gem 'simp-rspec-puppet-facts', ENV.fetch('SIMP_RSPEC_PUPPET_FACTS_VERSION', '~> 3.7')
end

group :development do
  gem 'pry'
  gem 'pry-byebug'
  gem 'pry-doc'
end

group :system_tests do
  gem 'bcrypt_pbkdf'
  gem 'beaker'
  gem 'beaker-rspec'
  gem 'simp-beaker-helpers', ENV.fetch('SIMP_BEAKER_HELPERS_VERSION', ['>= 1.32.1', '< 2'])
end

# Evaluate extra gemfiles if they exist
extra_gemfiles = [
  ENV.fetch('EXTRA_GEMFILE', ''),
  "#{__FILE__}.project",
  "#{__FILE__}.local",
  File.join(Dir.home, '.gemfile'),
]
extra_gemfiles.each do |gemfile|
  if File.file?(gemfile) && File.readable?(gemfile)
    eval(File.read(gemfile), binding) # rubocop:disable Security/Eval
  end
end
