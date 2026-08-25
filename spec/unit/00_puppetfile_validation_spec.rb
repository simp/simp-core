require 'json'
require 'spec_helper'

describe 'Puppetfile Validation' do
  top_dir = File.absolute_path(File.join(__dir__, '..', '..'))

  before(:each) do
    @tmpdir = Dir.mktmpdir
  end

  after(:each) do
    FileUtils.remove_entry(@tmpdir)
  end

  Dir.glob("#{top_dir}/Puppetfile.*") do |puppetfile|
    context "for '#{puppetfile}'" do
      it 'should be a valid Puppetfile' do
        Dir.chdir(@tmpdir) do
          FileUtils.cp(puppetfile, 'Puppetfile')
          msg = %x(r10k puppetfile check 2>&1).strip

          expect(msg).to match(/OK/)
        end
      end

      it 'should not have duplicate :git sources' do
        git_refs = {}
        duplicate_refs = {}
        mod = nil

        File.read(puppetfile).each_line do |line|
          if line =~ /mod ('|")(.+?)('|")/
            mod = $2
          end

          if line =~ /:git\s+=>\s+('|")(.+?)('|")/
            _src = $2

            git_refs[_src] ||= []
            git_refs[_src] << mod
          end
        end

        git_refs.each_pair do |k,v|
          (duplicate_refs[k] = git_refs[k]) if (v.size > 1)
        end

        expect(duplicate_refs).to be_empty, "Duplicate :git sources found:\n#{JSON.pretty_generate(duplicate_refs)}"
      end
    end
  end
end
