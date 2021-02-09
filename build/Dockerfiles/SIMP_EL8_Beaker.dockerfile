# This Dockerfile targets running accpetance tests using Beaker

FROM centos:8
ENV container docker

RUN mkdir /root/build_scripts
ADD scripts/el8/* /root/build_scripts

WORKDIR /root/build_scripts
RUN chmod +x *

RUN ./00_system_prep.sh
RUN ./10_dev_packages.sh
RUN yum -y update

CMD ['/sbin/init']
