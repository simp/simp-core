# SIMP Dockerfiles

These files are meant to assist with various SIMP build activities

Please read each file for details as to the purpose and usage of the file

## Helper Scripts

There are helper scripts in the `scripts` directory that you may find useful if
you are setting up your own development system from scratch.

## Building

`buildah build -t <friendly image name> -f <Dockerfile> .`

### Build args

The `SIMP_*_Build.dockerfile` builds support a `--build-arg` to set the initial
`ruby_version` of RVM:

```
buildah build -t simp_build_centos8_ruby3_1  --build-arg ruby_version=3.1 -f SIMP_EL8_Build.dockerfile
```

The current default for this argument is `2.7` (to support Puppet 7)


## Pushing

If you build using `buildah`, you'll need to make sure you push to Dockerhub
using `podman push --format=docker ...`

