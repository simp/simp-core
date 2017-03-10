SIMP build directory

1. [Build Directory](#build-directory)
2. [Existing Individual Distribution Directories](#existing-individual-distribution-directories)
  1. [yum_data](#yum_data)
  2. [DVD](#dvd)
  3. [release_mappings.yaml](#release_mappingsyaml)
  4. [mock.cfg](#mockcfg)
  5. [GPGKEYS](#GPGKEYS)
3. [Directories created by the build process](#directories-created-by-the-build-process)


## Build Directory

The build directory contains distribution/architecture specific build information.

The build_metadata.yaml file dictates the default build infrastructure for the
supported SIMP operating systems.  Each distribution/architecture is listed in
the file with a boolean "build".  If build is set to true, then rake build::auto
will build that ISO if no specific distribution is set.  (Read the information in
he top of the build_metadata.yaml file to see how to set a specific distro/arch to build.

The distribution directory contains all the files needed for each distribution in the format

distribution/DISTRIBUTION NAME/MAJOR RELEASE/ARCHITECTURE.


## Existing Individual Distribution Directories

Each individual Distribution directory, such as distribtution/CentOS/6/x86_64,
will contain  the files and directories needed to build that ISO.  The ISO
will be placed here in a directory called SIMP_ISO when it is built.

(Note:  these directories used to be located under simp-core/src/DVD in each git branch)

The following directories and files are present in each distribution:


### DVD
    This directory houses the files used to kickstart the DVD and also the files
    simp provides as templates to kickstart servers/clients for this version in
    /var/www/ks.

### release_mappings.yaml
  This file houses the *officially supported* SIMP release combinations
  Other build combinations may work, but unexpected issues may arise.

### mock.cfg
  The configuration file for the mock environment used to build the DVD.

### GPGKEYS
  A collection of GPG Keys required for repos used by SIMP.

### yum_data
  This directory structure assists in the building of a particular release of
SIMP with all of the correct RPM package dependencies.

YUM is used to download the various components so that anyone can build a
release of SIMP given their own internal YUM repositories.

The following describes the directories and files and how to use them to 
modify the build. 

#### my_repos/

Any YUM repo files that exist here will be used *instead* of the default repos.

NOTE: If you wish to use repos from the default then you **must** copy them here!

#### repos/

The default repos that will be used if nothing is present in *my_repos*.

#### packages.yaml

The actual list of packages that will be used for this build.

If a package cannot be found, this is a failing build error.

This file contains a hash of the following form:

```yaml
 ---
 'full_package_name_with_version' :
   source: 'http://the_full_download_location'
```
#### packages/

The actual packages for the given build.
If a package listed in _packages.yaml_ cannot be found here, it will be
downloaded via YUM.

If a package exists in this directory and does **not** exist in
the _packages.yaml_ file. It will be sourced via YUM and the YAML file will
be updated.

NOTE: This means that, to remove a package from a build, you need to remove it
manually from both packages.yaml **and** from this directory!


## Directories created by the build process

The following directories will be created when rake build::auto is run


### SIMP directories

SIMP, SIMP_ISO and SIMP_STAGING are all created under the architecture
directory of the distibution when rake build::auto is run.

SIMP  contains all the simp RPMS and SRPMS built.
SIMP_ISO_STAGING will contain the distibutions DVD packages
     and files from the DVD provided.  These are pruned using
     the *_simp_pkglist.txt in the DVD directory.
SIMP_ISO contains the final product of the SIMP iso and json
     files.

To remove these directories use the SIMP_BUILD_rm_staging_dir=yes
environment variable.

### DVD_Overlay 

This directory is also created under the architure directory for
each distribution and will contain the tar file of all the simp
rpms.
