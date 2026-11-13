# frozen_string_literal: true

# Shared helpers for the whole-stack checks in spec/stack. These tests look
# at the SIMP module set as a whole (a Puppetfile installed by
# `rake stack:install`), not at any single module, so each module stays
# usable on its own while simp-core catches drift between them.
#
# Environment variables (set by rakelib/stack.rake):
#   STACK_PUPPETFILE  Puppetfile suffix: `pinned` (default) or `branches`
#   STACK_MODULEDIR   Directory the Puppetfile was installed into
#   STACK_SKELETON    simp-environment-skeleton checkout (catalog checks)

require 'json'
require 'yaml'
require 'semantic_puppet'

module StackHelper
  BASE_DIR = File.expand_path('../..', __dir__)

  module_function

  def puppetfile
    ENV.fetch('STACK_PUPPETFILE', 'pinned')
  end

  def work_dir
    File.join(BASE_DIR, 'tmp', 'stack', puppetfile)
  end

  def moduledir
    ENV.fetch('STACK_MODULEDIR', File.join(work_dir, 'modules'))
  end

  def skeleton_dir
    ENV.fetch('STACK_SKELETON', File.join(BASE_DIR, 'tmp', 'stack', 'simp-environment-skeleton'))
  end

  # name used in dependency lists ("owner/name"), normalized
  def normalize(name)
    name.tr('-', '/')
  end

  # { 'name' => metadata } keyed by the module's short name (what r10k
  # installs it as), for every installed module
  def installed_modules
    @installed_modules ||= Dir[File.join(moduledir, '*', 'metadata.json')].sort.to_h do |f|
      [File.basename(File.dirname(f)), JSON.parse(File.read(f))]
    end
  end

  def allowlist
    @allowlist ||= YAML.safe_load_file(File.join(__dir__, 'dependency_allowlist.yaml')) || []
  end

  def allowed?(mod, dep)
    allowlist.any? do |e|
      (e['module'] == '*' || normalize(e['module']) == normalize(mod)) && normalize(e['dependency']) == normalize(dep)
    end
  end

  # Problems with one dependency entry of `mod` against the installed set.
  # Returns [failures, warnings].
  def check_dependency(mod, dep, optional:)
    failures = []
    warnings = []
    dep_name = normalize(dep['name'])
    req = dep['version_requirement'] || '>= 0'
    have = installed_modules[dep_name.split('/', 2).last]

    if have.nil?
      return [[], []] if optional || allowed?(mod, dep_name)

      return [["requires #{dep_name} #{req}, which is not installed"], []]
    end

    if normalize(have['name']) != dep_name
      msg = "#{'optionally ' if optional}requires #{dep_name}, but the installed module of that name is #{normalize(have['name'])}"
      (optional ? warnings : failures) << msg unless allowed?(mod, dep_name)
      return [failures, warnings]
    end

    range = SemanticPuppet::VersionRange.parse(req)
    version = SemanticPuppet::Version.parse(have['version'])
    unless range.include?(version)
      failures << "#{'optionally ' if optional}requires #{dep_name} #{req}, but #{have['version']} is installed"
    end

    [failures, warnings]
  end

  def check_module(metadata)
    mod = normalize(metadata['name'])
    failures = []
    warnings = []
    (metadata['dependencies'] || []).each do |dep|
      f, w = check_dependency(mod, dep, optional: false)
      failures += f
      warnings += w
    end
    (metadata.dig('simp', 'optional_dependencies') || []).each do |dep|
      f, w = check_dependency(mod, dep, optional: true)
      failures += f
      warnings += w
    end
    [failures, warnings]
  end

  # Warnings for `requirements` that exclude the OpenVox versions SIMP
  # supports. Many community modules haven't widened these yet, and Puppet
  # doesn't enforce them, so they are reported but don't fail.
  def requirement_warnings(metadata, majors = [8, 9])
    reqs = metadata['requirements'] || []
    req = reqs.find { |r| r['name'] == 'openvox' } || reqs.find { |r| r['name'] == 'puppet' }
    return ['has no openvox or puppet requirement'] if req.nil?

    range = SemanticPuppet::VersionRange.parse(req['version_requirement'] || '>= 0')
    majors.select { |m| range.intersection(SemanticPuppet::VersionRange.parse(">= #{m}.0.0 < #{m + 1}.0.0")) == SemanticPuppet::VersionRange::EMPTY_RANGE }.map do |m|
      "#{req['name']} #{req['version_requirement']} excludes #{m}.x"
    end
  end
end
