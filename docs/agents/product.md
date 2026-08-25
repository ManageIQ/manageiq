# Product Overview

ManageIQ is an open source hybrid-cloud management platform that provides a single management plane for virtual, cloud, container, and physical infrastructure.

- Website: https://manageiq.org
- GitHub org: https://github.com/ManageIQ

## High-level architecture

```
Providers → collect inventory / events / metrics
         → normalize into PostgreSQL (VMDB)
         → all features read from VMDB
         → operations posted back to native provider
```

Provider workers run as `MiqWorker` subclasses (separate OS processes). Many providers support event-streaming for near real-time collection. All domain objects (VMs, hosts, clusters, networks, etc.) are stored as ActiveRecord models and shared across all features.

## Key database tables

Some tables are central to understanding how ManageIQ works. An agent should know these exist even if it doesn't know the full schema:

| Table / model | Purpose |
|---|---|
| `ext_management_systems` / `ExtManagementSystem` | All providers (VMs, containers, physical, cloud, etc.) |
| `vms` / `VmOrTemplate` | VMs and templates across all infra/cloud providers |
| `miq_queue` / `MiqQueue` | Async work queue — almost all background work is enqueued here |
| `miq_tasks` / `MiqTask` | Tracks long-running operations triggered by users |
| `miq_requests` / `MiqRequest` | Lifecycle requests (provision, retire, reconfigure, etc.) |
| `metrics` / `Metric` | Realtime C&U data |
| `metric_rollups` / `MetricRollup` | Hourly/daily rolled-up C&U data |
| `miq_workers` / `MiqWorker` | Active worker process records |
| `users`, `miq_groups`, `miq_user_roles`, `miq_product_features` | RBAC — see [`architecture.md`](architecture.md) |
| `tenants` / `Tenant` | Multi-tenancy scoping |
| `ems_events` / `EmsEvent` | Provider events (power on/off, create, etc.) |

## Providers

Providers are the integration point with external systems. Each provider type has an abstract base class in this repo; the concrete implementation lives in a separate gem (`manageiq-providers-<name>`). Provider plugins have their own development conventions; see [`provider_plugins.md`](provider_plugins.md).

The system supports several types of providers: Infrastructure, Cloud, Containers, Physical, Network, Storage, Automation, and Configuration.

See [all provider plugins](https://github.com/ManageIQ?q=manageiq-providers-) for the full list of concrete provider implementations.

## Resource management

Agents working on resource management features should be aware of the following:

- **Managed object types**: VMs, instances, containers (pods/nodes/projects), hosts, clusters, datastores, networks, physical servers, etc. Each is a separate model hierarchy rooted in an abstract base class.
- **Operations** (power on/off, shutdown guest, reset, pause, suspend): implemented as `supports` flags + provider-specific methods. The `Supports` concern (`app/models/concerns/supports/`) gates which operations are available for a given object.
- **Lifecycle**: Provision, Clone, Reconfigure, Delete, Retirement. Provisioning goes through `MiqProvisionRequest` / `MiqProvision`; retirement through `RetirementManager`.
- **VM console access**: VNC/SPICE/WebMKS/HTML5 console support; protocol varies by provider.
- **Monitoring**: utilization data collected via metrics workers into `Metric` / `MetricRollup`; event timelines via `EmsEvent`.
- **SmartState Analysis**: deep introspection of VM/template filesystems. Extracts files, packages, services, accounts, Windows registry entries. Implemented via `VmScan` / `JobProxyDispatcher`.
- **Optimization / right-sizing**: recommendations based on utilization rollups stored in `MetricRollup`.
- **Custom buttons and dialogs**: `CustomButton` / `CustomButtonSet` attach to any object type; dialog authoring is in `Dialog` / `DialogField` models. Fields can be dynamic (backed by Automate methods).

## Tagging

Tags are first-class citizens. Nearly every managed object supports tagging.

- `Tag` and `Tagging` models; the `acts_as_miq_taggable` concern wires an object into the system.
- Tag taxonomy: `Classification` (categories) → `Tag` (entries).
- Tag mapping: provider-native tags (e.g. AWS labels) are mapped to ManageIQ tags via `TagMapping`.
- Tag-based RBAC is enforced by `Rbac::Filterer` — see [`architecture.md`](architecture.md).

## Dashboards and reporting

- **Dashboards**: `MiqDashboard` model; widgets (`MiqWidget`) are reusable tiles (charts, reports, RSS). Dashboards can be group-owned or user-owned.
- **Reports**: `MiqReport` covers any database entity and its relationships; supports scheduling (`MiqSchedule`), email delivery, and export to PDF/CSV/TXT. Report results stored in `MiqReportResult`.
- **Utilization reports**: rolled-up C&U data from `MetricRollup`.
- **Dashboard widgets**: `MiqWidget` can render a chart, a report table, or an RSS feed inside a dashboard.

## Chargeback

- **Rate cards**: `ChargebackRate` with `ChargebackRateDetail` entries for CPU, memory, storage, and network.
- **Rate assignment**: `ChargebackRateDetailMeasure` + tag/resource assignments connect rate cards to groups of resources.
- **Reports**: `ChargebackVm`, `ChargebackContainerProject`, etc. aggregate cost data; generated and stored like standard `MiqReport` results.

## Service catalog

The service catalog provides end-user self-service ordering. Key models:

- `ServiceTemplate` — a catalog item definition; subclassed per type (VM provision, Ansible playbook, Terraform template, orchestration, etc.).
- `ServiceTemplateProvisionRequest` / `ServiceTemplateProvisionTask` — the lifecycle of an order.
- `Service` — a deployed service instance; can own resources (VMs, etc.).
- `Dialog` / `DialogField` — custom ordering forms; fields can be dynamic (backed by Automate).
- `ServiceTemplateCatalog` — groups `ServiceTemplate` records for UI presentation.
- **Catalog item types**:
  - Cloud/infra VM templates
  - Ansible Playbook jobs
  - Orchestration templates (CloudFormation, Azure ARM, OpenStack Heat, vCloud vApp, VMware OVF)
  - Generic (custom Automate-backed)
- **Catalog bundles**: `ServiceTemplate` with child items; supports sequenced provisioning of multiple items in a single order.
- **Service lifecycle**: provisioning → reconfigure → retirement; each phase has request/task pairs and Automate entry points.

## Policy (Event-Condition-Action)

- `MiqPolicy` — defines a control or compliance policy.
- `MiqPolicySet` — a named set of policies assigned to objects via tags.
- **Control policies**: fire an `MiqAction` when an `MiqEvent` matches and `MiqCondition`s are satisfied.
- **Compliance policies**: evaluate conditions and mark objects `compliant` / `non_compliant` via `ComplianceDetail`.
- **Alerts**: `MiqAlert` watches metric thresholds and trends; fires `MiqAlertStatus` records and can trigger actions.
- **Actions** (`MiqAction`): run an Automate method, perform a provider operation, send email, create an incident, etc.
- **Policy simulation**: test which policies would fire for a given object/event without side effects.

## Automation

### Embedded Automate Engine

- Domain/namespace/class/method hierarchy stored in `MiqAeDomain`, `MiqAeNamespace`, `MiqAeClass`, `MiqAeMethod`.
- Methods are Ruby or Ansible; called from policy actions, service lifecycle, custom buttons, or directly via API.
- Entry points resolved by the Automate path (e.g. `/ManageIQ/System/Process/request`).
- The `MiqAeEngine` drives execution; workspace state passed via `MiqAeWorkspace`.
- Reference: _Mastering CloudForms Automation_ (Peter McGowan) for in-depth engine internals.

### Embedded Ansible

- Runs `ansible-cli` as a subprocess without requiring an external AWX/Tower provider.
- Playbooks imported from Git repositories (`ConfigurationScriptSource`).
- Execution tracked via `ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job`.

### Embedded Terraform

- Runs `terraform` CLI as a subprocess.
- Templates imported from Git repositories (`ConfigurationScriptSource` with type `ManageIQ::Providers::EmbeddedTerraform::...`).

### Embedded Workflows

- Custom workflow engine using Amazon States Language (ASL).
- Built on the [`floe`](https://github.com/ManageIQ/floe) open source gem.
- Workflows stored as `ManageIQ::Providers::EmbeddedWorkflows::...` records; execution tracked via `Floe::Workflow`.

## Authentication and authorization

- **RBAC**: `User`, `MiqGroup`, `MiqUserRole`, `MiqProductFeature`. Access checked via `Rbac::Filterer`; see [`rbac.md`](rbac.md) for details.
- **Multi-tenancy**: `Tenant` model; every group belongs to a tenant; resources are scoped by tenant ownership.
- **External auth**: OIDC, SAML, LDAP, Active Directory, IPA (with AD Trust and 2FA). Configured via `MiqServer` settings. External groups mapped to ManageIQ groups via `ExternalAuthenticationSettings` / group-mapping configuration.
- **Audit logging**: `AuditEvent` model; written via `$audit_log` global. All significant user/system actions should produce an audit event.

## Deployment

Understanding deployment helps when working on multi-region, worker, or settings-related code.

- **Appliance**: one or more VMs each running the full stack (UI, workers, database). Multiple appliances can be added to an installation for horizontal scaling.
- **Podified** (Operator-based): Kubernetes deployment via the [`manageiq-operator`](https://github.com/ManageIQ/manageiq-operator). Each component (UI, API, workers) runs as a separate pod.
- **Installation / Region**: a ManageIQ installation is a *region* — one or more appliances sharing a single PostgreSQL database. Multiple regions can replicate into a *Global Region* (also called a *super-region*) for centralized reporting. `MiqRegion`, `MiqRegionRemote`, and the `ActiveRecord::IdRegions` concern handle cross-region identity.
- **High availability**: active/passive failover for the application tier; PostgreSQL HA via external tooling.
- **MiqServer**: the in-process server record (`MiqServer`) tracks zone/region membership, active roles (server roles), and worker lifecycle.
- **Zones**: logical groupings of servers (`MiqServer`) within a region; used to direct work to specific sets of workers.
