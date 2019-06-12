require 'spec_helper_integration'
require 'json'
require 'yaml'

test_name 'simp::server::rsync_shares'

describe 'install rsync from GitHub (not rpm) and test simp::server::rsync_shares' do

  masters     = hosts_with_role(hosts, 'master')
  agents      = hosts_with_role(hosts, 'agent')
  master_fqdn = fact_on(master, 'fqdn')

  context 'master' do
    masters.each do |master|
      it 'should prepare the rsync server environment' do
        # FIXME This test does not adequately set up the rsync environment
        tmpdir = create_tmpdir_on(master)
        # master.install_package('selinux-policy-devel')

        script = <<-EOF
          mkdir -p /var/simp/environments/production/rsync
          git clone https://github.com/simp/simp-rsync.git #{tmpdir}
          rm -rf /var/simp/environments/production/rsync
          mv -f #{tmpdir}/environments/production/rsync /var/simp/environments/production/
          ln -s /var/simp/environments/production/rsync/RedHat /var/simp/environments/production/rsync/CentOS
          chmod u+rwx,g+rX,o+rX /var/simp{,/environments,/environments/production}

          # SELinux fixes
          # setfacl --restore=/var/simp/environments/production/rsync/.rsync.facl 2>/dev/null
          # cd #{tmpdir}/build/selinux; make -f /usr/share/selinux/devel/Makefile
          # cp #{tmpdir}/build/selinux/simp-rsync.pp /usr/share/selinux/packages
          # semodule -n -i /usr/share/selinux/packages/simp-rsync.pp
          # load_policy
          # fixfiles -R simp-rsync restore
        EOF
        on(master, script)
      end
      it 'should mock freshclam' do
        master.install_package('clamav-update')
        ## # Uncomment to use real FreshClam data from the internet
        ## create_remote_file(master, '/tmp/freshclam.conf', <<-EOF.gsub(/^\s+/,'')
        ##     DatabaseDirectory /var/simp/environments/production/rsync/Global/clamav
        ##     DatabaseMirror database.clamav.net
        ##     Bytecode yes
        ##   EOF
        ## )
        ## on(master, 'freshclam -u root --config-file=/tmp/freshclam.conf')
        ## on(master, 'chown clam.clam /var/simp/environments/production/rsync/Global/clamav/*')
        ## on(master, 'chmod u=rw,g=rw,o=r /var/simp/environments/production/rsync/Global/clamav/*')

        # Mock ClamAV data by just `touch`ing the data files
        on(master, 'touch /var/simp/environments/production/rsync/Global/clamav/{daily,bytecode,main}.cvd')
      end

      it 'modify the existing hieradata' do
        hiera = YAML.load(on(master, 'cat /etc/puppetlabs/code/environments/production/data/default.yaml').stdout)
        default_yaml = hiera.merge(
          'simp_options::rsync'  => true,
          'simp_options::clamav' => true,
          'simp::scenario::base::rsync_stunnel' => master_fqdn
        ).to_yaml
        create_remote_file(master, '/etc/puppetlabs/code/environments/production/data/default.yaml', default_yaml)
      end
    end
  end

  context 'agents' do
    it 'set up and run puppet' do
      block_on(agents, :run_in_parallel => false) do |agent|
        retry_on(agent, 'puppet agent -t',
          :desired_exit_codes => [0],
          :retry_interval     => 15,
          :max_retries        => 3,
          :verbose            => true.to_s # work around beaker bug
        )
      end
    end
  end
end
