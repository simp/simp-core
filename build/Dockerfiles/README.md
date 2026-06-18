# SIMP Dockerfiles

These files assist with various SIMP build and test activities. There are two
families of image, and they run **different** sets of scripts:

| Image family | Dockerfiles | Purpose |
|---|---|---|
| **Beaker SUT** | `SIMP_EL*_Beaker.dockerfile` | Minimal, systemd-enabled containers used by Beaker as acceptance-test nodes (systems under test). They do **not** contain Ruby or an agent — Beaker installs the OpenVox/Puppet agent at test time. Published as `ghcr.io/simp/simp-el<N>-beaker`. |
| **ISO build** | `SIMP_EL*_Build.dockerfile` | Full dev/build toolchain (mise-managed Ruby, rpmbuild, ISO tooling) for building SIMP ISOs and RPMs as the unprivileged `build_user`. |

## Helper Scripts

Scripts live under `scripts/`. `scripts/common/` is shared; `scripts/el8/`,
`scripts/el9/`, and `scripts/el10/` hold per-release variants. Each Dockerfile
`ADD`s the common scripts plus the matching per-release directory, so a
per-release script of the same name overrides the common one.

Every script carries a header comment describing its purpose and which image
family uses it. In summary:

| Script | Purpose | Used by |
|---|---|---|
| `common/minimize_package_installs.sh` | Configure dnf for a minimal footprint (no docs/weak deps, single langpack); refresh TLS trust + curl | both |
| `common/package_cleanup.sh` | Clear dnf caches and delete stray doc files to shrink the image | both |
| `el*/00_system_prep.sh` | Install dnf config-manager, bake in minimization settings, rebuild rpmdb, install yum-utils | both |
| `common/beaker_packages.sh` | Install the baseline userland a Beaker node needs | Beaker SUT |
| `common/container_safe_services.sh` | Install a systemd unit that strips container-incompatible directives from unit files | Beaker SUT |
| `el*/00_setup_vault.sh` | Pin repos to AlmaLinux Vault at the oldest point release for a stable library floor | ISO build |
| `el*/05_selinux.sh` | Downgrade to the vault baseline and install SELinux policy/tooling | ISO build |
| `el*/10_dev_packages.sh` | Install the full ISO/RPM build toolchain | ISO build |
| `common/user.sh` | Create the `build_user` build account | ISO build |
| `el*/install_mise.sh` | Install [mise](https://mise.jdx.dev) system-wide (per-release repo setup) | ISO build |
| `common/mise.sh` | Provision Ruby (3.2 + 4.0) for `build_user` via mise and install bundler | ISO build |
| `common/prime_ruby.sh` | Clone simp-core and `bundle install` to warm the gem cache | ISO build |

All scripts use `set -euo pipefail` so a failing step aborts the image build
instead of silently producing a broken image.

## Building

`buildah build -t <friendly image name> -f <Dockerfile> .`

### Build args

The `SIMP_*_Build.dockerfile` builds support a `--build-arg` to set the default
`ruby_version` that mise activates. Both Ruby **3.2** and **4.0** are always
installed; the build arg only selects which is the global default:

```
buildah build -t simp_build_el8_ruby40 --build-arg ruby_version=4.0 -f SIMP_EL8_Build.dockerfile
```

The default for this argument is `3.2`:

- Ruby **3.2** → OpenVox 8 (current)
- Ruby **4.0** → OpenVox 9 (upcoming)

## Pushing

Images are published to the GitHub Container Registry (`ghcr.io`). If you build
with `buildah`, push using `podman push --format=docker ...`. CI publishing is
handled by `.github/workflows/build_containers.yml`.
