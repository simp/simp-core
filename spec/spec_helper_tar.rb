require 'beaker-rspec'
require 'tmpdir'
require 'yaml'
require 'simp/beaker_helpers'
include Simp::BeakerHelpers

module SimpCoreTest
 # NOTE:  These passwords will be enclosed in single quotes when used on
 #        the shell command line. So, to simplify the code that uses
 #        them, these passwords should not contain single quotes.
 TEST_PASSWORDS = [ "P@ssw0rdP@ssw0rd", "Ch@ng3d=P@ssw0r!" ]
end

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
  tarball = ENV['BEAKER_release_tarball']
  #If tarball is not defined, check for one in the build directory
  if ( tarball.nil? or tarball.empty? )
    tarball = Dir.glob("build/distributions/#{osname}/#{relver}/x86_64/DVD_Overlay/SIMP*.tar.gz")[0]
  end
# If it begins with https: then download it from that URL
  if tarball =~ /https/
    filename = "SIMP-downloaded-#{osname}-#{relver}-x86_64.tar.gz"
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
        tarball = nil 
      end
    end
  end 
  tarball
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

def internet_deprepo(host)
  reponame = ENV['BEAKER_repo']
  reponame ||= '6_X'
  on(host, "curl -s https://packagecloud.io/install/repositories/simp-project/#{reponame}_Dependencies/script.rpm.sh | bash")
end

# Returns the plain-text, test password for the index specified
#
def test_password(index = 0)
  SimpCoreTest::TEST_PASSWORDS[index]
end

# FIXME: Workaround for SIMP-5082
# Using the (ASSUMED) optional, final command line argument in an expect
# script, adjust ciphers used by that script to ssh from src_host to
# dest_host, if necessary.  This ugly adjustment is needed in order to
# deal with different cipher sets configured by SIMP for sshd for CentOS 6
# versus CentOS 7.
#
# Returns the expect command
def adjust_ssh_ciphers_for_expect_script(expect_cmd, src_host, dest_host)
  cmd = expect_cmd.dup
  src_os_major  = fact_on(src_host, 'operatingsystemmajrelease')
  dest_os_major = fact_on(dest_host, 'operatingsystemmajrelease')
  if src_os_major.to_s == '7'
    cmd +=" '-o MACs=hmac-sha1'" if (dest_os_major.to_s == '6')
  elsif src_os_major.to_s == '6'
    cmd +=" '-o MACs=hmac-sha2-256'" if (dest_os_major.to_s == '7')
  end
  cmd
end

RSpec.configure do |c|
  # ensure that environment OS is ready on each host
  # fix_errata_on hosts

  # Readable test descriptions
  c.formatter = :documentation

end
