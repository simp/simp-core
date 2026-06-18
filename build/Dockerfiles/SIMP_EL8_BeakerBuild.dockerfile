# Beaker-runnable AlmaLinux 9 image WITH the SIMP RPM build environment.
#
# Unions the beaker base image (SIMP_EL8_Beaker.dockerfile) with the build
# toolchain, build_user, and RVM from SIMP_EL8_Build.dockerfile, MINUS the
# ISO-builder-only steps:
#
#   * 00_setup_vault.sh  - pins every repo to the 9.0 vault. Undesirable for a
#                          test image: the SUT should track current packages
#                          (e.g. it installs the current OpenVox release).
#   * 05_selinux.sh      - downgrades packages back toward the vault pin and is
#                          coupled to 00_setup_vault.sh.
#
# Build/publish via simp-core's .github/workflows/build_containers.yml:
#   dockerfile = SIMP_EL8_BeakerBuild.dockerfile
#   image_name = simp-el8-beaker-build
#   ruby_version = 3.3

FROM almalinux:8
ENV container docker
ARG ruby_version=3.3

RUN mkdir /root/build_scripts
ADD scripts/common/* /root/build_scripts/
ADD scripts/el8/*    /root/build_scripts/
WORKDIR /root/build_scripts
RUN chmod +x *

# --- beaker base (mirrors SIMP_EL8_Beaker.dockerfile) ---
RUN ./00_system_prep.sh
RUN ./minimize_package_installs.sh
RUN ./beaker_packages.sh
RUN ./container_safe_services.sh

# --- build environment (from SIMP_EL8_Build.dockerfile) ---
RUN ./10_dev_packages.sh
RUN ./user.sh build_user
RUN ./rvm.sh build_user "$ruby_version"
# Silence RVM's PATH-mismatch warning so it cannot pollute captured stdout
RUN echo 'rvm_silence_path_mismatch_check_flag=1' > /etc/profile.d/00_rvm_silence.sh

# --- finalize ---
RUN yum -y update
RUN ./package_cleanup.sh
RUN rm -rf /root/build_scripts

WORKDIR /home/build_user
CMD [ "/sbin/init" ]
