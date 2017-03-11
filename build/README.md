SIMP build directory

1. [The build/ Directory](#the-build/-directory)
2. [The build/distributions/ Directory](#the-build/distributions/-directory)
  1. [build_metadata.yaml](#build_metadata.yaml)
3. [The Architecture Directory](#the-architecture-directory)
  1. [DVD/](#dvd/)
  2. [release_mappings.yaml](#release_mappingsyaml)
  3. [mock.cfg](#mockcfg)
  4. [GPGKEYS/](#gpgkeys/)
  5. [yum_data/](#yum_data/)
    1. [my_repos/](#my_repos/)
    2. [repos/](#repos/)
    3. [packages.yaml](#packages.yaml)
    4. [packages/](#packages/)
  6. [Directories Created By The Build Process](#directories-created-by-the-build-process)
    1. [SIMP Directories](#simp-directories)
    2. [DVD_Overlay/](#dvd-overlay/)

## The build/ Directory
* Contains distribution/architecture specific build information
* Home to this awesome README

## The build/distributions/ Directory
* Contains the files needed to build each distribution
* Formatted as `build/distributions/DISTRIBUTION_NAME/MAJOR_RELEASE/ARCHITECTURE`
  For example, `distribtutions/CentOS/6/x86_64/`

### build_metadata.yaml
* Dictates the build infrastructure for supported SIMP operating systems.
* Each distribution/architecture is listed in the file with a boolean "build".
  If build is set to true, then rake build::auto will build that ISO if no
  specific distribution is set.
* See the top of the file learn how to set a specific distro/arch to build

## The Architecture Directory
Located under `build/distributions/DISTRIBUTION_NAME/MAJOR_RELEASE/ARCHITECTURE`

The following files are present in every distribution's architecture directory.

### DVD/
* Contains the DVD kickstart files and the SIMP kickstart templates
  (found in /var/www/ks on a SIMP system).

### release_mappings.yaml
* This file houses the *officially supported* SIMP releases
* Other build combinations may work, but unexpected issues may arise.

### mock.cfg
* The configuration file for the mock environment used to build the DVD.

### GPGKEYS/
* A collection of GPG Keys required for repos used by SIMP.

### yum_data/
* This directory structure assists in the building of a particular release of
  SIMP with all of the correct RPM package dependencies.

* YUM is used to download the various components so that anyone can build a
  release of SIMP given their own internal YUM repositories.

The following describes the directories and files and how to use them to
modify the build.

#### my_repos/
* Any YUM repo files that exist here will be used *instead* of the default repos.
* If you wish to use repos from the default then you **must** copy them here!

#### repos/
* The default repos that will be used if nothing is present in *my_repos*.

#### packages.yaml
* The master list of external packages that will be used for the build.
* If a package cannot be found, your build will fail.

This file contains a hash of the following form:

```yaml
 ---
 'full_package_name_with_version' :
   source: 'http://the_full_download_location'
```
#### packages/
* Contains the external packages necessary for a build, including the packages
  downloaded via `packages.yaml`
* If a package listed in `packages.yaml` does not exist in packages/, it will be
  downloaded via YUM.
* If a package exists in this directory and does **not** exist in the `packages.yaml` file,
  it will be sourced via YUM and `packages.yaml` will be automatically updated.
* To remove a package from a build, you need to remove it from `packages.yaml` **and**
  from this directory!

### Directories created by the build process
The following directories will be created under the architecture directory,
when rake build::auto is run.

#### SIMP Directories
`SIMP`, `SIMP_ISO` and `SIMP_STAGING` are all created under the when rake build:auto is run.
To remove these directories use the SIMP_BUILD_rm_staging_dir=yes environment variable.

* `SIMP` contains all the simp RPMS and SRPMS built.
* `SIMP_ISO_STAGING` contains the packages and files from the provided distrtibution DVD.
   These are pruned using the _simp_pkglist.txt in the DVD directory.
* `SIMP_ISO` contains the SIMP ISO and associated JSON files built via build:auto.

#### DVD_Overlay/
* Contains the tar file of the simp rpms generated during build:auto.
