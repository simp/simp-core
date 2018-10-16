# -*- mode: ruby -*-
Vagrant.configure("2") do |config|
  config.vm.box = "centos/7"
  config.vm.box_version = "1708.01"

  config.vm.synced_folder ".", "/vagrant", user: 'vagrant', group: 'vagrant',
                          type: "rsync", rsync_auto: true, rsync__args: ['--archive']

  config.vm.provision "shell", path: 'build/setup/privileged.sh'
  config.vm.provision "shell", privileged: false, path: 'build/setup/not_privileged.sh'  
end
