# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## What is simp-core?

simp-core is the metamodule (supermodule) for SIMP — it aggregates 100+ Puppet module dependencies, defines the overall release, and houses the build infrastructure for producing SIMP ISOs and RPM packages. It does not contain Puppet manifests of its own.

## Common Commands

```bash
bundle install                        # Install Ruby dependencies

# Linting / validation
bundle exec rake check:syntax:yaml    # Validate YAML under build/, .github/, top-level
bundle exec rake check:pkglist_lint   # Verify package list files are sorted correctly
bundle exec rake metadata_lint        # Validate metadata.json

# Dependency management (r10k)
bundle exec rake deps:checkout        # Check out all Puppetfile modules into src/
bundle exec rake deps:clean           # Remove checked-out dependencies

# Module status checks (queries GitHub and Puppet Forge)
bundle exec rake puppetfile:check     # Check all pinned modules against GitHub/Forge
bundle exec rake puppetfile:check_module[module_name]  # Check a single module

# Build artifacts
bundle exec rake pkg:build_clean      # Remove built RPM/ISO artifacts

# Change tracking between releases
bundle exec rake deps:changes_since[prev_tag]  # EXPERIMENTAL: generate changelog diff
```

## Architecture

### Puppetfiles

Two Puppetfile variants exist:
- **`Puppetfile.pinned`** (← `Puppetfile.tracking` symlink) — production; all components pinned to exact tags; used for releases
- **`Puppetfile.branches`** — development; tracks branches for in-flight work

r10k uses `moduledir 'src'` (Puppet modules) and `moduledir 'src/assets'` (non-module SIMP assets like simp-cli, simp-environment, simp-utils). After `deps:checkout`, the full tree is under `src/`.

### Rake Tasks (rakelib/)

| File | Purpose |
|---|---|
| `deps.rake` | r10k checkout/clean, change-tracking between releases |
| `puppetfile.rake` | Module release status (GitHub releases + Puppet Forge + local reposync) |
| `pkg.rake` | Clean build artifacts under `build/distributions/` |
| `yamllint.rake` | YAML syntax validation |
| `pkglist_lint.rake` | RPM package list ordering checks |
| `simp_core_deps_helper.rb` | Shared helpers: changelog diffs, component version extraction, git log gathering |

The Rakefile also loads `simp-rake-helpers` (`Simp::Rake::Build::Helpers`) which provides the broader ISO/RPM build pipeline (may emit a warning if the gem isn't installed).

### Build Infrastructure (`build/`)

- `build/distributions/` — per-distro configs (CentOS 7, RedHat 7/8); each distro/version/arch directory contains:
  - `mock.cfg` — Mock RPM build environment
  - `yum_data/` — repo configs and `packages.yaml` (external package manifest)
  - `release_mappings.yaml` — official SIMP releases for that distro
  - Output dirs created at build time: `SIMP/`, `SIMP_ISO/`, `SIMP_ISO_STAGING/`
- `build/Dockerfiles/` — Docker images for isolated build (`SIMP_EL7_Build`, `SIMP_EL8_Build`) and acceptance testing (`SIMP_EL7_Beaker`, `SIMP_EL8_Beaker`)
- `build/metadata.yaml` — controls which distros are enabled for builds; override with `SIMP_BUILD_distro=CentOS,7,x86_64`

### CI (`.github/workflows/`)

- **`pr_checks.yml`** — runs on PRs: YAML lint, RPM file checks (`rake check:dot_underscore`, `rake check:test_file`), metadata lint, and `pdk build`; sets `SIMP_RPM_dist=.el7`
- **`build_containers.yml`** — manual workflow to build and push Docker build/test images to a registry

### Gemfile Notes

- `PUPPET_VERSION` env var pins Puppet gem (default: `>= 7, < 9`)
- `GEM_SERVERS` env var overrides gem sources
- Optional extra Gemfiles: `Gemfile.project`, `Gemfile.local`, `~/.gemfile`
- `PDK_DISABLE_ANALYTICS=true` is set automatically
