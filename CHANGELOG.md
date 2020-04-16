# CHANGELOG

## Release 2.5.0 (in development)

### Features Added
- Upgrade Calico to 3.12.0 (PR [#2253](https://github.com/scality/metalk8s/pull/2253))
- Extend the set of packages installed in the `metalk8s-utils` container image
  (Partially resolves issue [#2156](https://github.com/scality/metalk8s/issues/2156),
  PR [#2374](https://github.com/scality/metalk8s/pull/2374))
- Upgrade `containerd` to 1.2.13 (PR [#2369](https://github.com/scality/metalk8s/pull/2369))
- Enable `seccomp` support in `containerd`
  (Issue [#2259](https://github.com/scality/metalk8s/issues/2259),
  PR [#2369](https://github.com/scality/metalk8s/pull/2369))