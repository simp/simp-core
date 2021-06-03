gem_sources = ENV.fetch('GEM_SERVERS','https://rubygems.org').split(/[, ]+/)

ENV['PDK_DISABLE_ANALYTICS'] ||= 'true'

gem_sources.each { |gem_source| source gem_source }

group :test do
  puppet_version = ENV['PUPPET_VERSION'] || '~> 6.18'
  major_puppet_version = puppet_version.scan(/(\d+)(?:\.|\Z)/).flatten.first.to_i
  gem 'rake'
  gem 'puppet', puppet_version
  gem 'rspec'
  gem 'rspec-puppet'
  gem 'hiera-puppet-helper'
  gem 'puppetlabs_spec_helper'
  gem 'metadata-json-lint'
  gem 'puppet-strings'
  gem 'puppet-lint-empty_string-check',   :require => false
  gem 'puppet-lint-trailing_comma-check', :require => false
  gem 'simp-rspec-puppet-facts', ENV['SIMP_RSPEC_PUPPET_FACTS_VERSION'] || '~> 3.1'
  gem 'simp-rake-helpers', ENV['SIMP_RAKE_HELPERS_VERSION'] || ['> 5.11', '< 6.0']
  gem 'simp-build-helpers', ENV['SIMP_BUILD_HELPERS_VERSION'] || ['> 0.1', '< 2.0']
  gem( 'pdk', ENV['PDK_VERSION'] || '~> 1.0', :require => false) if major_puppet_version > 5

  # minimum versions for deps to address vulnerabilities, etc
  gem 'nokogiri', '>= 1.11.6' # mitigates CVE-2021-3517 et al.
end

group :development do
  gem 'pry'
  gem 'pry-byebug'
  gem 'pry-doc'
end

group :system_tests do
  gem 'beaker', '~> 4.27.1'
  gem 'beaker-rspec'
  gem 'simp-beaker-helpers', ENV['SIMP_BEAKER_HELPERS_VERSION'] || ['>= 1.21.4', '< 2']
end

# Evaluate extra gemfiles if they exist
extra_gemfiles = [
  ENV['EXTRA_GEMFILE'] || '',
  "#{__FILE__}.project",
  "#{__FILE__}.local",
  File.join(Dir.home, '.gemfile'),
]
extra_gemfiles.each do |gemfile|
  if File.file?(gemfile) && File.readable?(gemfile)
    eval(File.read(gemfile), binding)
  end
end
