# SIMP Dockerfiles

These files are meant to assist with various SIMP build activities

Please read each file for details as to the purpose and usage of the file

## Helper Scripts

There are helper scripts in the `scripts` directory that you may find useful if
you are setting up your own development system from scratch.

## Building

`buildah bud -t <friendly image name> -f <Dockerfile> .`

## Pushing

If you build using `buildah`, you'll need to make sure you push to Dockerhub
using `podman push --format=docker ...`
