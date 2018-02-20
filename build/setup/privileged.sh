# Install epel repo. Needed for 'haveged'
yum install -y epel-release

# Install/start haveged to keep entropy pool full
yum install -y haveged
systemctl start haveged
systemctl enable haveged

# Install/start Docker-CE
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce
systemctl enable docker
systemctl start docker
usermod -aG docker vagrant
echo "DOCKER_STORAGE_OPTIONS= --storage-opt dm.basesize=100G" > /etc/sysconfig/docker-storage

# Install git 
yum install -y git

# Install RPM/ISO build tools
yum install -y rpm-build rpm-sign createrepo genisoimage
