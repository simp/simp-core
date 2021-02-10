# This Dockerfile targets running acceptance tests using Beaker

FROM centos:8
ENV container docker

RUN mkdir /root/build_scripts
ADD scripts/el8/* /root/build_scripts
ADD scripts/common/* /root/build_scripts

WORKDIR /root/build_scripts
RUN chmod +x *

RUN ./00_system_prep.sh
RUN ./minimize_package_installs.sh
RUN ./beaker_packages.sh
RUN ./container_safe_services.sh
RUN yum -y update
RUN ./package_cleanup.sh
RUN rm -rf /root/build_scripts

WORKDIR /root

CMD [ "/sbin/init" ]
