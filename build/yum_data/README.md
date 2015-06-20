# SIMP YUM Data

## Purpose

This directory structure assists in the building of a particular release of
SIMP with all of the correct RPM package dependencies.

YUM is used to download the various components so that anyone can build a
release of SIMP given their own internal YUM repositories.

## How to Use This Space

The general structure of this space is as follows:

### my_repos/

Any Yum repo files that exist here will be used for ALL systems!

### SIMP{:simp_version}_{:os}{:os_version}_{:arch}/

The base directory holding all metadata for the given distribution

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
