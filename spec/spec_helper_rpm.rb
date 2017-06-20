require 'beaker-rspec'
require 'tmpdir'
require 'yaml'
require 'simp/beaker_helpers'
include Simp::BeakerHelpers

unless ENV['BEAKER_provision'] == 'no'
  hosts.each do |host|
    # Install Facter for beaker helpers
    host.install_package('rubygems')
    on(host, 'gem install facter')
    on(host, 'echo export PATH=$PATH:/usr/local/bin > /root/.bashrc')
  end
end

# Find a release tarball
def find_tarball(relver,osname)
# set the tar ball using environment variable 'BEAKER_release_tarball'
# If it begins with https: then download it from that URL
  tarball = ENV['BEAKER_release_tarball']
  #If tarball is not defined, check for one in the build directory
  if ( tarball.nil? or tarball.empty? )
    tarball = Dir.glob("build/distributions/#{osname}/#{relver}/x86_64/DVD_Overlay/SIMP*.tar.gz")[0]
  end
  if tarball =~ /https/
    filename = 'SIMP-downloaded-CentOS-7-x86_64.tar.gz'
    url = "#{tarball}"
    require 'net/http'
    Dir.exists?("spec/fixtures") || Dir.mkdir("spec/fixtures")
    File.write("spec/fixtures/#{filename}", Net::HTTP.get(URI.parse(url)))
    tarball = "spec/fixtures/#{filename}"
    warn("Found tarball.  Downloaded from #{url}")
  else
    if not ( tarball.nil? or tarball.empty? )
      if File.exists?(tarball)
        warn("Found Tarball: #{tarball}")
      else
        warn("Tarball #{tarball} not found, will use Project repos")
        #Set tarball to empty so it will use project repos
        tarball = ''
      end
    end
  end 
  tarball
end

def find_reponame
  reponame = ENV['BEAKER_reponame']
  reponame ||= '6_X'
  warn("Using SIMP reponame #{reponame}")
  reponame
end

def tarball_yumrepos(host, tarball)
  warn('='*72)
  warn("Found Tarball: #{tarball}")
  warn('Test will continue by setting up a local repository on the master from the tarball')
  warn('='*72)


  host.install_package('createrepo')
  scp_to(host, tarball, '/root/')
  tarball_basename = File.basename(tarball)
  on(host, "mkdir -p /var/www && cd /var/www && tar xzf /root/#{tarball_basename}")
  on(host, 'createrepo -q -p /var/www/SIMP/noarch')
  create_remote_file(host, '/etc/yum.repos.d/simp_tarball.repo', <<-EOF.gsub(/^\s+/,'')
    [simp-tarball]
    name=Tarball repo
    baseurl=file:///var/www/SIMP/noarch
    enabled=1
    gpgcheck=0
    repo_gpgcheck=0
    EOF
  )
  on(host, 'yum makecache')
end

# Install the packagecloud yum repos
# See https://packagecloud.io/simp-project/ for the reponame key
def internet_simprepo(host, reponame)
  if reponame !~ /manual/
    warn('='*72)
    warn('Using Internet repos from packagecloud for testing')
    warn('If you do not want to use the project repos ')
    warn('Specify a tarball with BEAKER_release_tarball or by placing one in the build DVD_Overlay directory')
    warn('='*72)

    on(host, "curl -s https://packagecloud.io/install/repositories/simp-project/#{reponame}/script.rpm.sh | bash")
  else
    warn('Internet yumrepos disabled, modify nodeset to add manual repos')
  end
end

def internet_deprepo(host, reponame)
  on(host, "curl -s https://packagecloud.io/install/repositories/simp-project/#{reponame}_Dependencies/script.rpm.sh | bash")
end



RSpec.configure do |c|
  # ensure that environment OS is ready on each host
  # fix_errata_on hosts

  # Readable test descriptions
  c.formatter = :documentation

end
