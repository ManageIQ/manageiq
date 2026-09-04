# Build and Packaging

ManageIQ ships as both an appliance (virtual-machine image) and a container (Kubernetes/OpenShift pod). The build pipeline lives in four separate repositories; this repository (`manageiq`) is the application source that all of them consume.

## Build repositories

| Repository | Purpose |
|---|---|
| [`manageiq-rpm_build`](https://github.com/ManageIQ/manageiq-rpm_build) | Produces RPM packages for all ManageIQ components and their dependencies. Drives the nightly and release RPM build pipeline. |
| [`manageiq-appliance-build`](https://github.com/ManageIQ/manageiq-appliance-build) | Assembles virtual-machine appliance images (QCOW2, OVA, VHD, etc.) from the RPMs produced by `manageiq-rpm_build`. |
| [`manageiq-appliance`](https://github.com/ManageIQ/manageiq-appliance) | OS-level configuration and firstboot scripts that run inside the appliance image — service units, network configuration, initial database setup, etc. |
| [`manageiq-pods`](https://github.com/ManageIQ/manageiq-pods) | Kubernetes/OpenShift deployment manifests and operator for running ManageIQ as a containerised workload. |

## Relationship to this repository

Changes to `manageiq` (and its plugin gems) flow into builds as follows:

1. **RPM build** — `manageiq-rpm_build` pulls gem sources, installs them into a build root, and packages them as RPMs. Version pins and gem sources are controlled there.
2. **Appliance image** — `manageiq-appliance-build` installs the RPMs from step 1 into a base OS image, then applies the configuration layer from `manageiq-appliance`.
3. **Container image** — `manageiq-pods` builds OCI images by installing the same RPMs from step 1 into a container base image, then provides the Kubernetes manifests and operator to deploy them.

When making changes that affect startup, required OS packages, or service configuration, coordinate with the `manageiq-appliance` and `manageiq-pods` repositories in addition to this one.

## Branches and release cadence

- The `master` branch of this repository tracks the next release.
- Named release branches correspond to stable releases; branches are named after chess grandmasters (e.g., `spassky`, `tal`). The build repositories have matching branches.
- On release branches, `Gemfile.lock.release` pins gem versions; update both `Gemfile.lock` and `Gemfile.lock.release` when changing gem dependencies on a release branch.
