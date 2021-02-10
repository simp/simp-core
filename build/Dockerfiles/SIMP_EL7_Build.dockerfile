# This Dockerfile begins from an ancient version of CentOS and upgrades itself
# in order to acquire all the accumulated SELinux contexts starting from EL7.0
# until the present.
#
# To build using docker, run:
#
# ```sh
# docker build \
#   --tag "simp-core-iso-builder:el7.$(git rev-parse --short HEAD)" \
#   --file build/Dockerfiles/SIMP_EL7_Build.dockerfile
# ```
#
# To build using podman, run:
# ```sh
# podman build \
#   --tag "simp-core-iso-builder:el7.$(git rev-parse --short HEAD)" \
#   --file build/Dockerfiles/SIMP_EL7_Build.dockerfile
# ```
#
# After building, you will probably want to mount your ISO directory using
# something like the following:
#
# ```sh
# docker run -v $PWD/ISO:/ISO:Z -it <container ID>
# ```
#
# If you want to save your container for future use, you use use the `docker
# commit` command
#   * docker commit <running container ID> el7_build
#   * docker run -it el7_build

FROM centos:7.0.1406
ENV container docker

RUN mkdir /root/build_scripts
ADD scripts/common/* /root/build_scripts/
ADD scripts/el7/* /root/build_scripts/

WORKDIR /root/build_scripts
RUN chmod +x *

RUN ./00_system_prep.sh
RUN ./minimize_package_installs.sh
RUN ./01_disable_systemctl.sh
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
