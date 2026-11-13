# frozen_string_literal: true

# Compiles full-stack catalogs: a Puppet environment built from
# simp-environment-skeleton (hiera.yaml, scenario data, site.pp) and the
# modules installed from a Puppetfile, for each SIMP scenario and each
# supported EL major release. This catches breakage that no single module's
# tests can see, such as a compliance profile that references a module SIMP
# no longer ships, or a module asserting an optional dependency version.
#
# A compile error, or any error-level message logged while compiling, fails
# the example.
#
# Run with `bundle exec rake stack:catalogs[pinned]` (or `[branches]`).

# Each catalog is compiled once in a before(:all) block and shared by the
# examples that check it; compiling per example would multiply the run time.
# rubocop:disable RSpec/BeforeAfterAll, RSpec/InstanceVariable

require_relative 'stack_helper'
require 'fileutils'
require 'puppet'
require 'rspec'
require 'simp/rspec-puppet-facts'

module StackCatalogs
  extend Simp::RspecPuppetFacts

  SCENARIOS = ['simp', 'simp_lite', 'poss'].freeze
  OS_RELEASES = ['8', '9', '10'].freeze
  CERTNAME = 'node.example.com'

  # Stand-in for what `simp config` writes for a new site
  SIMP_CONFIG_SETTINGS = {
    'simp_options::trusted_nets' => ['10.0.0.0/8'],
    'simp_options::puppet::server' => 'puppet.example.com',
    'simp_options::puppet::ca' => 'puppet.example.com',
    'simp_grub::admin' => 'root',
    'simp_grub::password' => 'grub.pbkdf2.sha512.10000.ABCD',
  }.freeze

  module_function

  def skeleton_env
    File.join(StackHelper.skeleton_dir, 'environments', 'puppet')
  end

  def environmentpath
    File.join(StackHelper.work_dir, 'environments')
  end

  def hiera_levels
    YAML.safe_load_file(File.join(skeleton_env, 'hiera.yaml'))['hierarchy'] || []
  end

  def compliance_engine_level?
    hiera_levels.any? { |level| level['lookup_key'] == 'compliance_engine::enforcement' }
  end

  # Modules whose namespaced Hiera backend functions (e.g.
  # compliance_engine::enforcement) hiera.yaml uses but which aren't installed
  def missing_backend_modules
    keys = ['lookup_key', 'data_hash', 'data_dig']
    hiera_levels.flat_map { |level| level.values_at(*keys).compact }
                .select { |f| f.include?('::') }
                .map { |f| f.split('::').first }
                .uniq
                .reject { |m| StackHelper.installed_modules.key?(m) }
  end

  # Build environments/<scenario> from the skeleton and the installed modules
  def build_environment(scenario)
    env = File.join(environmentpath, scenario)
    FileUtils.rm_rf(env)
    FileUtils.mkdir_p(env)
    ['hiera.yaml', 'data', 'manifests'].each { |p| FileUtils.cp_r(File.join(skeleton_env, p), env) }
    FileUtils.ln_s(StackHelper.moduledir, File.join(env, 'modules'))

    site_pp = File.join(env, 'manifests', 'site.pp')
    content = File.read(site_pp)
    raise "#{site_pp} doesn't set $simp_scenario" unless content.match?(%r{^\$simp_scenario\s*=})

    File.write(site_pp, content.sub(%r{^\$simp_scenario\s*=.*$}, "$simp_scenario = '#{scenario}'"))
    File.write(File.join(env, 'data', 'simp_config_settings.yaml'), SIMP_CONFIG_SETTINGS.to_yaml)
    env
  end

  # Facts for each EL release, as an OpenVox 8+ agent sends them: without the
  # legacy fqdn/hostname/domain facts
  def os_facts
    @os_facts ||= on_supported_os(
      supported_os: [{ 'operatingsystem' => 'RedHat', 'operatingsystemrelease' => OS_RELEASES }],
    ).to_h do |os, facts|
      facts = JSON.parse(JSON.generate(facts))
      ['fqdn', 'hostname', 'domain'].each { |f| facts.delete(f) }
      facts['networking'] = (facts['networking'] || {}).merge(
        'fqdn' => CERTNAME, 'hostname' => 'node', 'domain' => 'example.com',
      )
      facts['clientcert'] = CERTNAME
      [os, facts]
    end
  end

  def init_puppet
    return if @puppet_initialized

    Puppet.initialize_settings(
      [
        '--confdir', File.join(StackHelper.work_dir, 'puppet', 'conf'),
        '--vardir', File.join(StackHelper.work_dir, 'puppet', 'var'),
        '--codedir', File.join(StackHelper.work_dir, 'puppet', 'code'),
        '--environmentpath', environmentpath,
        '--strict', 'warning'
      ],
    )
    @puppet_initialized = true
  end

  # Returns [catalog or nil, error message or nil, err-level log messages]
  def compile(environment, facts)
    collector = nil
    logs = []
    collector = Puppet::Test::LogCollector.new(logs)
    Puppet::Util::Log.newdestination(collector)
    node = Puppet::Node.new(CERTNAME, facts: Puppet::Node::Facts.new(CERTNAME, facts), environment: environment)
    node.add_server_facts({})
    trusted = Puppet::Context::TrustedInformation.new('remote', CERTNAME, {})
    catalog = Puppet.override(trusted_information: trusted) { Puppet::Parser::Compiler.compile(node) }
    [catalog, nil, error_logs(logs)]
  rescue StandardError => e
    [nil, e.message, error_logs(logs)]
  ensure
    Puppet::Util::Log.close(collector)
  end

  def error_logs(logs)
    logs.select { |l| [:err, :alert, :emerg, :crit].include?(l.level) }.map(&:message).uniq
  end
end

describe "Stack catalogs with Puppetfile.#{StackHelper.puppetfile}" do
  before(:all) do
    unless File.directory?(StackCatalogs.skeleton_env)
      raise "No simp-environment-skeleton at #{StackHelper.skeleton_dir}; run `rake stack:skeleton` first"
    end

    if StackHelper.installed_modules.empty?
      raise "Nothing installed in #{StackHelper.moduledir}; run `rake stack:install` first"
    end

    StackCatalogs.init_puppet
  end

  it 'installs every module that the skeleton hiera.yaml uses as a backend' do
    expect(StackCatalogs.missing_backend_modules).to be_empty,
      "hiera.yaml uses functions from modules that aren't in Puppetfile.#{StackHelper.puppetfile}: " \
      "#{StackCatalogs.missing_backend_modules.join(', ')}"
  end

  StackCatalogs::SCENARIOS.each do |scenario|
    context "with the #{scenario} scenario" do
      before(:all) do
        unless StackCatalogs.compliance_engine_level?
          skip('The skeleton hiera.yaml has no compliance_engine::enforcement level yet ' \
               '(simp/simp-environment-skeleton#75), so the SIMP modules would compile without simp:defaults')
        end
        unless StackCatalogs.missing_backend_modules.empty?
          skip("hiera.yaml needs modules that aren't installed: #{StackCatalogs.missing_backend_modules.join(', ')}")
        end

        StackCatalogs.build_environment(scenario)
      end

      StackCatalogs.os_facts.each do |os, facts|
        context "on #{os}" do
          before(:all) do
            @catalog, @error, @errors = StackCatalogs.compile(scenario, facts)
          end

          it 'compiles' do
            expect(@error).to be_nil
          end

          it 'logs no errors while compiling' do
            expect(@errors).to be_empty, "Errors logged:\n  #{@errors.join("\n  ")}"
          end

          next unless scenario == 'simp'

          it 'manages sshd through simp:defaults' do
            skip('the catalog did not compile') unless @catalog
            expect(@catalog.resource('Service[sshd]')).not_to be_nil
          end

          it 'does not include the archived tcpwrappers module' do
            skip('the catalog did not compile') unless @catalog
            expect(@catalog.classes).not_to include('tcpwrappers')
          end
        end
      end
    end
  end
end
# rubocop:enable RSpec/BeforeAfterAll, RSpec/InstanceVariable
