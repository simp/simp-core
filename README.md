## SIMP Core

This is the 4.2 series of the [SIMP](https://github.com/NationalSecurityAgency/SIMP) supermodule.


1. [Supported releases](#supported-releases)
2. [Building the SIMP ISO](#building-the-simp-iso)
  1. [Prerequisites](#prerequisites)
  2. [Quickstart](#quickstart)
  3. [Full build procedure](#full-procedure)
3. [Links](#links)


## Supported releases
This branch supports:
  - [RHEL 6.8](https://access.redhat.com/downloads/)
  - CentOS 6.8
    - [Disc 1](http://isoredirect.centos.org/centos/6.7/isos/x86_64/CentOS-6.7-x86_64-bin-DVD1.iso)
    - [Disc 2](http://isoredirect.centos.org/centos/6.7/isos/x86_64/CentOS-6.7-x86_64-bin-DVD2.iso)


## Building the SIMP ISO


**NOTE** The following examples use the Disc 1 and Disc 2 of the CentOS 6.8 distribution above.

### Prerequisites
   - You must first:
     - [Set up your build environment](https://simp-project.atlassian.net/wiki/display/SD/Setting+up+your+build+environment)
     - Download an appropriate source ISO to overlay (in this example CentOS-6.8 disks 1 and 2)
     - If building the release tarballs from scratch:
        - ~70GB free in the mock root directory (generally this is `/var/lib/mock`)

### Quickstart


The minimum necessary command to build SIMP from scratch is:
```bash
bundle exec rake build:auto[4.2.X,path/to/directory/holding/CentOS/ISOs]
```


If building from published [release tarball](https://bintray.com/simp/Releases/Artifacts/view#files):
```bash
bundle exec rake build:auto[4.2.X,path/to/directory/holding/CentOS/ISOs,path/to/SIMP-DVD-TARBALL]
```


### Full procedure
There is full procedure for [compiling the SIMP tarball and ISO](https://simp-project.atlassian.net/wiki/display/SD/Compiling+the+SIMP+Tarball+and+ISO) in the [SIMP Development](https://simp-project.atlassian.net/wiki/display/SD/) documentation.

## Links
- [SIMP master repository](https://github.com/NationalSecurityAgency/SIMP)
- [SIMP Development documentation](https://simp-project.atlassian.net/wiki/display/SD)
- [SIMP admin/user documentation](http://simp.readthedocs.org/en/latest/)
