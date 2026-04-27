# Build from the oldest AlmaLinux 9 release to accumulate SELinux contexts.
#
# To build using docker, run:
#
# ```sh
# docker build \
#   --tag "simp-core-iso-builder:el9.$(git rev-parse --short HEAD)" \
#   --file build/Dockerfiles/SIMP_EL9_Build.dockerfile \
#   build/Dockerfiles
# ```
#
# To build using podman, run:
# ```sh
# podman build \
#   --tag "simp-core-iso-builder:el9.$(git rev-parse --short HEAD)" \
#   --file build/Dockerfiles/SIMP_EL9_Build.dockerfile \
#   build/Dockerfiles
# ```
#
# After building, mount your ISO directory:
#
# ```sh
# docker run -v $PWD/ISO:/ISO:Z -it <container ID>
# ```

FROM almalinux:9.0
ENV container docker
ARG ruby_version=3.1

RUN mkdir /root/build_scripts
ADD scripts/common/* /root/build_scripts/
ADD scripts/el9/* /root/build_scripts/

WORKDIR /root/build_scripts
RUN chmod +x *

RUN ./00_setup_vault.sh
RUN ./00_system_prep.sh
RUN ./minimize_package_installs.sh
RUN ./05_selinux.sh
RUN ./10_dev_packages.sh
RUN ./user.sh
RUN ./rvm.sh build_user "$ruby_version"
RUN ./prime_ruby.sh
RUN ./package_cleanup.sh
RUN rm -rf /root/build_scripts

# Drop into a shell for building
CMD /bin/bash -c "su -l build_user"
