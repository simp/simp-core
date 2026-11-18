# frozen_string_literal: true

# Checks that the modules installed from a Puppetfile agree with each other:
# every module's `dependencies` and `simp.optional_dependencies` must be
# satisfied by the versions actually in the set. Each module's own CI tests
# it against its fixtures, so this is the only place that catches, for
# example, a module still capping a dependency below the version SIMP now
# ships.
#
# Run with `bundle exec rake stack:deps[pinned]` (or `[branches]`).

require_relative 'stack_helper'

describe "Module dependencies in Puppetfile.#{StackHelper.puppetfile}" do
  it 'has installed modules' do
    expect(StackHelper.installed_modules).not_to be_empty, "Nothing installed in #{StackHelper.moduledir}; run `rake stack:install` first"
  end

  StackHelper.installed_modules.each do |short_name, metadata|
    context "#{metadata['name']} #{metadata['version']}" do
      it 'has its dependencies satisfied by the module set' do
        failures, warnings = StackHelper.check_module(metadata)
        warnings.each { |w| RSpec.configuration.reporter.message("WARNING: #{metadata['name']}: #{w}") }
        expect(failures).to be_empty, "#{short_name}:\n  #{failures.join("\n  ")}"
      end

      it 'supports OpenVox 8 and 9 (warning only)' do
        StackHelper.requirement_warnings(metadata).each do |w|
          RSpec.configuration.reporter.message("WARNING: #{metadata['name']}: #{w}")
        end
      end
    end
  end

  if StackHelper.puppetfile == 'pinned'
    context 'simp-core metadata.json' do
      it 'has every dependency satisfied by Puppetfile.pinned' do
        core = JSON.parse(File.read(File.join(StackHelper::BASE_DIR, 'metadata.json')))
        failures = (core['dependencies'] || []).flat_map do |dep|
          StackHelper.check_dependency(core['name'], dep, optional: false).first
        end
        expect(failures).to be_empty, "metadata.json:\n  #{failures.join("\n  ")}"
      end
    end
  end
end
