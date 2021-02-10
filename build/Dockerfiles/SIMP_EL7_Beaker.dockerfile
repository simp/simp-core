# This Dockerfile targets running acceptance tests using Beaker

FROM centos:7
ENV container docker

RUN mkdir /root/build_scripts
ADD scripts/el7/* /root/build_scripts
ADD scripts/common/* /root/build_scripts

WORKDIR /root/build_scripts
RUN chmod +x *

RUN ./00_system_prep.sh
RUN ./minimize_package_installs.sh
RUN ./base_packages.sh
RUN ./03_enable_systemd.sh
RUN ./container_safe_services.sh
RUN yum -y update
RUN ./package_cleanup.sh

CMD ['/sbin/init']
