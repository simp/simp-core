# Gemfile for bundler (gem install bundler)
#
# To update all gem dependencies:
#
#   bundle
#
# To run a rake task:
#
is_ruby_old = Gem::Version.new( RUBY_VERSION ) < Gem::Version.new( '1.9' )
warn( "WARNING: ruby #{RUBY_VERSION} detected!" +
        " Any ruby version below 1.9 may have issues." ) if is_ruby_old

# Allow a comma or space-delimited list of gem servers
if simp_gem_server =  ENV.fetch( 'SIMP_GEM_SERVERS', false )
  simp_gem_server.split( / |,/ ).each{ |gem_server|
    source gem_server
  }
end
source 'https://rubygems.org'

# read dependencies in from the gemspec
gemspec

# mandatory gems
gem 'bundler'
#  gem 'rake'
#  gem 'highline', '~> 1.6.1'  # NOTE: 1.7+ requires ruby 1.9.3+
#  gem 'puppet'
#  gem 'facter'



group :testing do
  # bootstrap common environment variables
  gem 'dotenv'

  # Testing framework
  gem 'rspec'
  gem 'rspec-its'
end


# nice-to-have gems (for debugging)
group :development do
  # enhanced REPL + debugging environment
  gem 'pry', is_ruby_old ? '< 0.10' : nil
  gem 'pry-doc'
  gem 'pry-debugger'

  # Automatically test changes
  gem 'guard', is_ruby_old ? '< 2.0.0' : nil
  gem 'guard-shell'
  gem 'guard-rspec'
###   gem 'gem2rpm'
end
