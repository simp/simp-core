# ------------------------------------------------------------------------------
# NOTE: SIMP 6.x Puppet rake tasks support ruby 2.1.9
# ------------------------------------------------------------------------------
gem_sources   = ENV.fetch('SIMP_GEM_SERVERS', 'https://rubygems.org').split(/[, ]+/)
gem_sources.each { |gem_source| source gem_source }

group :test do
  gem "rake"
  gem 'puppet', ENV.fetch('PUPPET_VERSION', '~> 4')
  gem "rspec"
  gem "rspec-puppet"
  gem "hiera-puppet-helper"
  gem "puppetlabs_spec_helper"
  gem "metadata-json-lint"
  gem "simp-rspec-puppet-facts", ENV.fetch('SIMP_RSPEC_PUPPET_FACTS_VERSION', '~> 1.4')
  gem 'simp-rake-helpers',       ENV.fetch('SIMP_RAKE_HELPERS_VERSION', '~> 3')
  # Ruby code coverage
  gem 'simplecov'
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
  #gem 'beaker'
  # Need this for SELinux workarounds until the PR gets accepted
  gem 'beaker'
  gem 'beaker-rspec'
  gem 'simp-beaker-helpers', ENV.fetch('SIMP_BEAKER_HELPERS_VERSION', '>= 1.0.5')
end
