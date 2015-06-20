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
is_ruby_old = false
if Gem::Version.new( RUBY_VERSION ) < Gem::Version.new( '1.9' )
  warn( "WARNING: ruby #{RUBY_VERSION} detected!" +
        " Any ruby version below 1.9 will have issues." )
  is_ruby_old = true
end

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
gem 'simp-rake-helpers', '>=1.0.4'
gem 'parallel'
gem 'dotenv'
gem 'ruby-progressbar'

# nice-to-have gems (for debugging)
group :debug do
  gem 'pry'
  gem 'pry-doc'
  if is_ruby_old #ruby_version_below_1_9
    warn( "WARNING: skipping pry-debugger because ruby #{RUBY_VERSION}!" )
  else
    #gem 'pry-debugger'
  end
end

#vim: set syntax=ruby:

