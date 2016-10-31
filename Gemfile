# ------------------------------------------------------------------------------
# NOTE: SIMP Puppet rake tasks support ruby 2.0 and ruby 2.1
# ------------------------------------------------------------------------------
gem_sources   = ENV.key?('SIMP_GEM_SERVERS') ? ENV['SIMP_GEM_SERVERS'].split(/[, ]+/) : ['https://rubygems.org']
gem_sources.each { |gem_source| source gem_source }

# mandatory gems
gem 'bundler'
gem 'rake'
gem 'coderay'
gem 'puppet', ENV.fetch('PUPPET_VERSION',  '~>3')
gem 'puppet-lint'
gem 'puppetlabs_spec_helper'
gem 'simp-rake-helpers', '~>3.0'
gem 'simp-build-helpers', ENV.fetch('SIMP_BUILD_HELPERS_VERSION', '~> 0.1')
gem 'parallel'
gem 'dotenv'
gem 'ruby-progressbar'
gem 'google-api-client', '0.9.4'

# nice-to-have gems (for debugging)
group :debug do
  gem 'pry'
  gem 'pry-doc'
end

#vim: set syntax=ruby:
