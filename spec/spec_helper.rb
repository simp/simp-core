# frozen_string_literal: true
#
# ------------------------------------------------------------------------------
#         NOTICE: **This file is maintained with puppetsync**
#
# This file is automatically updated as part of a puppet module baseline.
# The next baseline sync will overwrite any local changes made to this file.
# ------------------------------------------------------------------------------

require 'puppetlabs_spec_helper/module_spec_helper'
require 'rspec-puppet'
require 'simp/rspec-puppet-facts'
include Simp::RspecPuppetFacts

require 'pathname'

# RSpec Material
fixture_path = File.expand_path(File.join(__FILE__, '..', 'fixtures'))
module_name = File.basename(File.expand_path(File.join(__FILE__, '../..')))

if ENV['PUPPET_DEBUG']
  Puppet::Util::Log.level = :debug
  Puppet::Util::Log.newdestination(:console)
end

default_hiera_config = <<~HIERA_CONFIG
---
version: 5
hierarchy:
  - name: SIMP Compliance Engine
    lookup_key: compliance_markup::enforcement
    options:
      enabled_sce_versions: [2]
  - name: Custom Test Hiera
    path: "%{custom_hiera}.yaml"
  - name: "%{module_name}"
    path: "%{module_name}.yaml"
  - name: Common
    path: default.yaml
defaults:
  data_hash: yaml_data
  datadir: "stub"
HIERA_CONFIG

# This can be used from inside your spec tests to set the testable environment.
# You can use this to stub out an ENC.
#
# Example:
#
# context 'in the :foo environment' do
#   let(:environment){:foo}
#   ...
# end
#
def set_environment(environment = :production)
  RSpec.configure { |c| c.default_facts['environment'] = environment.to_s }
end

# This can be used from inside your spec tests to load custom hieradata within
# any context.
#
# Example:
#
# describe 'some::class' do
#   context 'with version 10' do
#     let(:hieradata){ "#{class_name}_v10" }
#     ...
#   end
# end
#
# Then, create a YAML file at spec/fixtures/hieradata/some__class_v10.yaml.
#
# Hiera will use this file as it's base of information stacked on top of
# 'default.yaml' and <module_name>.yaml per the defaults above.
#
# Note: Any colons (:) are replaced with underscores (_) in the class name.
def set_hieradata(hieradata)
  RSpec.configure { |c| c.default_facts['custom_hiera'] = hieradata }
end

unless File.directory?(File.join(fixture_path, 'hieradata'))
  FileUtils.mkdir_p(File.join(fixture_path, 'hieradata'))
end

unless File.directory?(File.join(fixture_path, 'modules', module_name))
  FileUtils.mkdir_p(File.join(fixture_path, 'modules', module_name))
end

RSpec.configure do |c|
  # If nothing else...
  c.default_facts = {
    production: {
      #:fqdn           => 'production.rspec.test.localdomain',
      path: '/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin',
      concat_basedir: '/tmp'
    }
  }

  c.mock_framework = :rspec
  c.mock_with :rspec

  c.module_path = File.join(fixture_path, 'modules')
  c.manifest_dir = File.join(fixture_path, 'manifests') if c.respond_to?(:manifest_dir)

  c.hiera_config = File.join(fixture_path, 'hieradata', 'hiera.yaml')

  # Useless backtrace noise
  backtrace_exclusion_patterns = [
    %r{spec_helper},
    %r{gems},
  ]

  if c.respond_to?(:backtrace_exclusion_patterns)
    c.backtrace_exclusion_patterns = backtrace_exclusion_patterns
  elsif c.respond_to?(:backtrace_clean_patterns)
    c.backtrace_clean_patterns = backtrace_exclusion_patterns
  end

  # rubocop:disable RSpec/BeforeAfterAll
  c.before(:all) do
    data = YAML.safe_load(default_hiera_config)
    data.each_key do |key|
      next unless data[key].is_a?(Hash)

      if data[key][:datadir] == 'stub'
        data[key][:datadir] = File.join(fixture_path, 'hieradata')
      elsif data[key]['datadir'] == 'stub'
        data[key]['datadir'] = File.join(fixture_path, 'hieradata')
      end
    end

    File.open(c.hiera_config, 'w') do |f|
      f.write data.to_yaml
    end
  end
  # rubocop:enable RSpec/BeforeAfterAll

  c.before(:each) do
    @spec_global_env_temp = Dir.mktmpdir('simpspec')

    if defined?(environment)
      set_environment(environment)
      FileUtils.mkdir_p(File.join(@spec_global_env_temp, environment.to_s))
    end

    # ensure the user running these tests has an accessible environmentpath
    Puppet[:digest_algorithm] = 'sha256'
    Puppet[:environmentpath] = @spec_global_env_temp
    Puppet[:user] = Etc.getpwuid(Process.uid).name
    Puppet[:group] = Etc.getgrgid(Process.gid).name

    # sanitize hieradata
    if defined?(hieradata)
      set_hieradata(hieradata.gsub(':', '_'))
    elsif defined?(class_name)
      set_hieradata(class_name.gsub(':', '_'))
    end
  end

  c.after(:each) do
    # clean up the mocked environmentpath
    FileUtils.rm_rf(@spec_global_env_temp)
    @spec_global_env_temp = nil
  end
end

Dir.glob("#{RSpec.configuration.module_path}/*").each do |dir|
  begin
    Pathname.new(dir).realpath
  rescue StandardError
    raise "ERROR: The module '#{dir}' is not installed. Tests cannot continue."
  end
end
