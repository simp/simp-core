require 'beaker-rspec'
require 'tmpdir'
require 'simp/beaker_helpers'
include Simp::BeakerHelpers


# Install Facter for beaker helpers
unless ENV['BEAKER_provision'] == 'no'
    hosts.each do |host|
      host.install_package('rubygems')
      on(host, 'gem install facter')
      on(host, 'echo export PATH=$PATH:/usr/local/bin > /root/.bashrc')
    end
end


def setup_repo(host)
  reponame = ENV['BEAKER_repo']
  reponame ||= '6_X'
  if reponame[0] == '/' 
    setup_repo=copy_repo(host,reponame)
  else
    setup_repo=internet_simprepo(host, reponame)
  end 
  setup_repo
end

# Install the packagecloud yum repos
# See https://packagecloud.io/simp-project/ for the reponame key
def internet_simprepo(host, reponame)
    warn('='*72)
    warn("Using Internet repos from packagecloud for testing version #{reponame}")
    warn('='*72)

    on(host, "curl -s https://packagecloud.io/install/repositories/simp-project/#{reponame}/script.rpm.sh | bash")
    on(host, "curl -s https://packagecloud.io/install/repositories/simp-project/#{reponame}_Dependencies/script.rpm.sh | bash")
    internet_repo = true
end

def copy_repo(host,reponame)
  if File.exists(reponame)
    warn('='*72)
    warn("Using repos defined in #{reponame}")
    warn('='*72)
    text = File.read(reponame)
    repo_copied = create_remote_file(hosts,'/etc/yum.repo.d/simp_manual.repo',text)
  else 
    warn('='*72)
    warn("File #{reponame} could not be found")
    warn('='*72)
    repo_copied = false
  end
  repo_copied
end 


RSpec.configure do |c|
  # ensure that environment OS is ready on each host
  # fix_errata_on hosts

  # Readable test descriptions
  c.formatter = :documentation

end
