require 'spec_helper_integration'
require 'json'
require 'yaml'

test_name 'simp_kubernetes'

describe 'simp_kubernetes' do

  master_fqdn  = fact_on(master, 'fqdn')
  # domain       = fact_on(master, 'domain')
  kube_masters = hosts_with_role(hosts, 'kube-master')
  nodes        = hosts_with_role(hosts, 'kube-node')
  controller   = kube_masters.first
  cluster      = kube_masters.map{|h| fact_on(h,'fqdn') }

  it 'classify nodes' do
    base_hiera = YAML.load_file('spec/acceptance/suites/kubernetes/files/hieradata.yaml').merge({
        'simp_options::puppet::server'  => master_fqdn,
        'simp_options::puppet::ca'      => master_fqdn,
        'simp::yum::servers'            => [master_fqdn],
        'iptables::ignore'              => ['DOCKER','docker','KUBE-'],
        'simp_kubernetes::etcd_peers'   => Array(cluster),
        'simp_kubernetes::kube_masters' => Array(cluster),
        'simp_kubernetes::flannel_args' => {
          'iface' => 'eth1',
        },
      }
    )
    create_remote_file(master, '/etc/puppetlabs/code/environments/production/hieradata/default.yaml', base_hiera.to_yaml)

    site_pp = <<-EOF
      node default {
        include 'simp'
        include 'simp_kubernetes'
      }
      node /kube-master/ {
        include 'simp'
        class { 'simp_kubernetes':
          is_master => true,
        }
      }
      node /puppet/ {
        include 'simp'
        include 'simp::server'
        include 'pupmod'
        include 'pupmod::master'
      }
    EOF
    create_remote_file(master, '/etc/puppetlabs/code/environments/production/manifests/site.pp', site_pp)

    # fix perms
    on(master, 'chown -R root.puppet /etc/puppetlabs/code/environments/production/{hieradata,manifests}')
  end


  kube_masters.each do |host|
    it "should use puppet on #{host} to set up apiserver etc" do
      on(host, 'puppet agent -t', acceptable_exit_codes: [0,2,4,6])
      on(host, 'puppet agent -t', acceptable_exit_codes: [0,2])
    end
  end

  nodes.each do |host|
    it "should use puppet on #{host} to set up kubelets" do
      on(host, 'puppet agent -t', acceptable_exit_codes: [0,2,4,6])
      on(host, 'puppet agent -t', acceptable_exit_codes: [0,2])
    end
  end

  context 'check kubernetes health' do
    it 'should get componentstatus with no unhealthy components' do
      status = on(controller, 'kubectl get componentstatus')
      expect(status.stdout).not_to match(/Unhealthy/)
    end
  end

  context 'use kubernetes' do
    it 'should deploy a nginx service' do
      scp_to(controller, 'spec/acceptance/suites/kubernetes/files/test-nginx_deployment.yaml','/root/test-nginx_deployment.yaml')
      on(controller, 'kubectl create -f /root/test-nginx_deployment.yaml')
    end
    it 'should delete it' do
      sleep 30
      on(controller, 'kubectl delete service nginx-service')
      on(controller, 'kubectl delete deployment nginx-deployment')
    end
  end
end
