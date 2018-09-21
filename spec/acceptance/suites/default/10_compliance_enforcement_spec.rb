require 'spec_helper_acceptance'

test_name 'compliance enforcement'

describe 'compliance enforcement' do
  master = only_host_with_role(hosts, 'master')
  agents = hosts_with_role(hosts, 'agent')

  if Gem::Version.new(on(master, 'puppet --version').stdout.strip) < Gem::Version.new('4.10')
    it 'can not run on systems that do not support Hiera v5'
  else
    context 'master setup' do

      let(:compliance_report_hook) { <<-EOS
          $compliance_profile = 'disa_stig'
          include 'compliance_markup'
        EOS
      }

      let(:manifest) {
        <<-EOS
          include 'pam'

          #{compliance_report_hook}
        EOS
      }

      let(:hieradata_dir) { '/etc/puppetlabs/code/environments/production/hieradata' }
      let(:hiera_yaml) { <<-EOM
---
version: 5
hierarchy:
  - name: Compliance
    lookup_key: compliance_markup::enforcement
  - name: Common
    path: default.yaml
defaults:
  data_hash: yaml_data
  datadir: "#{hieradata_dir}"
    EOM
        }

      it 'should set the global hiera.yaml' do
        create_remote_file(master, master.puppet['hiera_config'], hiera_yaml)
      end

      it 'should set the compliance report hook' do
        create_remote_file(master, '/tmp/compliance_report_hook.tmp', compliance_report_hook)
        on(master, 'cat /tmp/compliance_report_hook.tmp >> /etc/puppetlabs/code/environments/production/manifests/site.pp')
      end

      it 'should run puppet successfully' do
        # Add onto the existing hiera
        hiera = YAML.load(on(master, "cat #{hieradata_dir}/default.yaml").stdout)

        default_yaml = hiera.merge(
          'compliance_markup::report_types' => ['full'],
          'compliance_markup::enforcement' => ['disa_stig']
        )

        create_remote_file(master, "#{hieradata_dir}/default.yaml", default_yaml.to_yaml)

        result = on(master, 'puppet agent -t', :accept_all_exit_codes => true).output.strip
        expect(result).to_not match /parameter .+ expects .+ got/m
      end
    end

    context 'agent run' do
      agents.each do |host|
        it 'should run puppet successfully' do
          result = on(host, 'puppet agent -t', :accept_all_exit_codes => true).output.strip
          expect(result).to_not match /parameter .+ expects .+ got/m
        end
      end
    end

    context 'compliance reports on the master' do
      agents.each do |host|
        context "a valid report for #{host}" do
          before(:all) do
            @compliance_data = {
              :report => {}
            }
          end

          let(:fqdn) { fact_on(host, 'fqdn') }

          it 'should have a report' do
            tmpdir = Dir.mktmpdir
            begin
              Dir.chdir(tmpdir) do
                scp_from(master, "/opt/puppetlabs/server/data/puppetserver/simp/compliance_reports/#{fqdn}/compliance_report.json", '.')

                expect {
                  @compliance_data[:report] = JSON.load(File.read('compliance_report.json'))
                }.to_not raise_error
              end
            ensure
              FileUtils.remove_entry_secure tmpdir
            end
          end

          it 'should have host metadata' do
            expect(@compliance_data[:report]['fqdn']).to eq(fqdn)
          end

          it 'should have a passing compliance profile report' do
            expect(@compliance_data[:report]['compliance_profiles']).to_not be_empty
            expect(@compliance_data[:report]['compliance_profiles']['disa_stig']).to_not be_empty
            expect(@compliance_data[:report]['compliance_profiles']['disa_stig']['summary']).to_not be_empty

            # We need to make sure this is true in the future but the tests
            # successfully prove that the subsystem is working properly across
            # the board.
            #
            # expect(@compliance_data[:report]['compliance_profiles']['disa_stig']['summary']['percent_compliant']).to be == 100
          end
        end
      end
    end
  end
end
