# This version of CentOS is needed for the SELinux context builds
# After building, you will probably want to mount your ISO directory using
# something like the following:
#   * docker run -v $PWD/ISO:/ISO:Z -it <container ID>
#
# If you want to save your container for future use, you use use the `docker
# commit` command
#   * docker commit <running container ID> el8_build
#   * docker run -it el8_build
#FROM centos:8
FROM centos:centos8.1.1911
ENV container docker

RUN mkdir /root/build_scripts
ADD scripts/common/* /root/build_scripts/
ADD scripts/el8/* /root/build_scripts/

WORKDIR /root/build_scripts
RUN chmod +x *

RUN ./00_system_prep.sh
RUN ./minimize_package_installs.sh
RUN ./05_selinux.sh
RUN ./10_dev_packages.sh
RUN ./user.sh
RUN ./rvm.sh
RUN ./prime_ruby.sh
RUN ./package_cleanup.sh
RUN rm -rf /root/build_scripts

WORKDIR /root

# Drop into a shell for building
CMD /bin/bash -c "su -l build_user"
