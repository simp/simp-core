# Gemfile for bundler (gem install bundler)
#
# To update all gem dependencies:
#
#   bundle
#
# To build a tar ball:
#   bundle exec rake tar:build[epel-6-x86_64]
# ruby=2.1


# watch the name, or RVM will flip out
source 'https://rubygems.org'

# Allow a comma or space-delimited list of gem servers
if simp_gem_server =  ENV.fetch( 'SIMP_GEM_SERVERS', false )
  simp_gem_server.split( / |,/ ).each{ |gem_server|
    source gem_server
  }
end


# mandatory gems
gem 'bundler'
gem 'rake'
gem 'coderay'
gem 'puppet'
gem 'puppet-lint'
gem 'puppetlabs_spec_helper'
gem 'simp-rake-helpers', :path => './src/rubygems/simp-rake-helpers'
gem 'parallel'
gem 'dotenv'
gem 'ruby-progressbar'

# nice-to-have gems (for debugging)
group :debug do
  gem 'pry'
  gem 'pry-doc'
end

#vim: set syntax=ruby:

