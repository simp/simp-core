# ------------------------------------------------------------------------------
# Environment variables:
#   SIMP_GEM_SERVERS | a space/comma delimited list of rubygem servers
#   PUPPET_VERSION   | specifies the version of the puppet gem to load
# ------------------------------------------------------------------------------
# NOTE: SIMP Puppet rake tasks support ruby 2.0 and ruby 2.1
# ------------------------------------------------------------------------------
gem_sources   = ENV.key?('SIMP_GEM_SERVERS') ? ENV['SIMP_GEM_SERVERS'].split(/[, ]+/) : ['https://rubygems.org']

gem_sources.each { |gem_source| source gem_source }

group :test do
  gem "rake", '< 11.0.1'
  gem 'puppet', ENV.fetch('PUPPET_VERSION',  '~>4')
  gem "rspec"
  gem "rspec-puppet"
  gem "hiera-puppet-helper"
  gem "puppetlabs_spec_helper"
  gem "metadata-json-lint"
  gem "simp-rspec-puppet-facts", ENV.fetch('SIMP_RSPEC_PUPPET_FACTS_VERSION', '~> 1.3')
  gem 'simp-rake-helpers', ENV.fetch('SIMP_RAKE_HELPERS_VERSION', '~> 3.0')
end

group :development do
  gem "travis"
  gem "travis-lint"
  gem "travish"
  gem "puppet-blacksmith"
  gem "guard-rake"
  gem 'pry'
  gem 'pry-doc'

  # `listen` is a dependency of `guard`
  # from `listen` 3.1+, `ruby_dep` requires Ruby version >= 2.2.3, ~> 2.2
  gem 'listen', '~> 3.0.6'
end

group :system_tests do
  gem 'beaker', :git => 'https://github.com/trevor-vaughan/beaker.git', :branch => 'BKR-931-2.51.0'
  gem 'beaker-rspec'
  gem 'simp-beaker-helpers', ENV.fetch('SIMP_BEAKER_HELPERS_VERSION', '~> 1.5')
end
