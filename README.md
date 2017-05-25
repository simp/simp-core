[![CII Best Practices](https://bestpractices.coreinfrastructure.org/projects/73/badge)](https://bestpractices.coreinfrastructure.org/projects/73)

This is the 6.X series of the [SIMP](https://github.com/NationalSecurityAgency/SIMP) supermodule.


1. [Supported releases](#supported-releases)
2. [Building the SIMP ISO](#building-the-simp-iso)
  1. [Prerequisites](#prerequisites)
  2. [Quickstart](#quickstart)
  3. [Full build procedure](#full-procedure)
3. [Links](#links)


## Supported releases
This branch supports:
  - RHEL 7.2
  - [CentOS 7 1511](http://isoredirect.centos.org/centos/7.2.1511/isos/x86_64/CentOS-7-x86_64-DVD-1511.iso)


## Building the SIMP ISO


**NOTE** The following examples use `CentOS-7-x86_64-DVD-1511.iso` as an overlay source.

### Prerequisites
   - You must first:
     - [Set up your build environment](https://simp-project.atlassian.net/wiki/display/SD/Setting+up+your+build+environment)
     - Download an appropriate source ISO to overlay (in this example CentOS-7-x86_64-DVD-1511.iso)
     - If building the release tarballs from scratch:
        - ~70GB free in the mock root directory (generally this is `/var/lib/mock`)

### Quickstart


The minimum necessary command to build SIMP from scratch is:
```bash
bundle exec rake build:auto[6.X,path/to/CentOS-7-x86_64-DVD-1511.iso]
```


If building from published [release tarball](https://bintray.com/artifact/download/simp/Releases/SIMP-DVD-CentOS-5.1.0-2.tar.gz):
```bash
bundle exec rake build:auto[6.X,path/to/CentOS-7-x86_64-DVD-1511.iso,path/to/SIMP-DVD-CentOS-6.0.0-0.tar.gz]
```


### Full procedure
There is full procedure for [compiling the SIMP tarball and ISO](https://simp-project.atlassian.net/wiki/display/SD/Compiling+the+SIMP+Tarball+and+ISO) in the [SIMP Development](https://simp-project.atlassian.net/wiki/display/SD/) documentation.

## Links
- [SIMP master repository](https://github.com/NationalSecurityAgency/SIMP)
- [SIMP Development documentation](https://simp-project.atlassian.net/wiki/display/SD)
- [SIMP admin/user documentation](http://simp.readthedocs.org/en/latest/)
