# Gemfile for bundler (gem install bundler)
#
# To update all gem dependencies:
#
#   bundle
#
# To run a rake task:
#
source 'https://rubygems.org'
# ruby '1.8.7'  # As of 03 Nov 2014, many top-level rake tasks only work in
                # 1.8.7.  However, the Gemfile will not enforce this as some
                # hosts' RVM installs use 1.8.7 builds that don't match '1.8.7'
                # FIXME: update rake tasks to work with newer ruby versions

# mandatory gems
gem 'bundler'
gem 'rake'
gem 'coderay'
gem 'puppet'
gem 'puppet-lint'
gem 'puppetlabs_spec_helper'
gem 'puppet_module_spec_helper'
gem 'minitest'

# nice-to-have gems (for debugging)
group :debug do
  gem 'pry'
  gem 'pry-doc'
  gem 'pry-debugger' # WARNING: does not work in ruby 1.8.7
  gem 'highline'
  gem 'hoe'
  gem 'hoe-bundler'
end
