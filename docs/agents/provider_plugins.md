# Provider Plugin Development

This document covers the architecture and conventions specific to ManageIQ provider plugins. Read [`plugins.md`](plugins.md) first for the general plugin conventions that also apply here.

## Manager model

Every provider has a top-level manager class that inherits from one of the abstract base classes in core:

| Manager type | Core base class |
|---|---|
| `CloudManager` | `ManageIQ::Providers::CloudManager` |
| `InfraManager` | `ManageIQ::Providers::InfraManager` |
| `ContainerManager` | `ManageIQ::Providers::ContainerManager` |
| `PhysicalInfraManager` | `ManageIQ::Providers::PhysicalInfraManager` |
| `NetworkManager` | `ManageIQ::Providers::NetworkManager` |
| `StorageManager` | `ManageIQ::Providers::StorageManager` |
| `AutomationManager` | `ManageIQ::Providers::AutomationManager` |
| `ConfigurationManager` | `ManageIQ::Providers::ConfigurationManager` |

All inventory objects (VMs, hosts, networks, etc.) are associated to the manager via `ems_id`. The root base class for all managers is `ExtManagementSystem` (`app/models/ext_management_system.rb` in core).

### Parent/child managers and the Provider record

Many providers decompose into a hierarchy:

- **`Provider`** (optional) — a top-level credential/connection record that owns one or more managers. For example, `ManageIQ::Providers::Openstack::Provider` holds credentials shared by its `CloudManager`, `NetworkManager`, and `StorageManager`.
- **Parent manager** — the primary manager (e.g. `CloudManager`); it handles refresh and credentials.
- **Child managers** — subordinate managers (e.g. `NetworkManager`, `StorageManager`) that are created automatically under the parent and share the parent's connection. They are associated via `parent_ems_id`.

Not every provider uses all three levels — simple providers may have only a single manager with no `Provider` record and no child managers.

## Inventory pipeline: Refresher → Collector → Parser → Persister

The `Refresher` class is the entrypoint for inventory collection. It is invoked by the `RefreshWorker` and orchestrates the full pipeline. Base classes for all pipeline stages live in core under `app/models/manageiq/providers/inventory/`.

### Refresh targets: full vs. targeted

Every refresh is driven by a target:

- **Full refresh** — a `ManagerRefresh::Target` that covers all objects managed by the EMS.
- **Targeted refresh** — a `TargetCollection` of specific `InventoryRefresh::Target` objects (each identified by an association name + `manager_ref`). The `Collector` uses this collection to narrow the API calls it makes; the `Persister` uses it to define the *targeted scope*, which prevents deletion of records that were not part of this refresh.

### Pipeline stages

| Stage | Base class (core) | Responsibility |
|---|---|---|
| `Refresher` | `ManageIQ::Providers::BaseManager::Refresher` | Entrypoint; receives targets, builds the pipeline, drives Collector → Parser → Persister |
| `Collector` | `ManageIQ::Providers::Inventory::Collector` | Fetch raw data from the provider API; cache it for the parser; respects targeted scope |
| `Parser` | `ManageIQ::Providers::Inventory::Parser` | Map raw data to ManageIQ inventory object hashes |
| `Persister` | `ManageIQ::Providers::Inventory::Persister` | Declares a set of `InventoryCollection`s; drives upsert/disconnect/deletion |

### InventoryCollection

Each `InventoryCollection` represents either a Rails association (e.g. `:vms`, `:hosts`) or a custom save block. The persister uses them to perform upsert, disconnect, and deletion of stale records in a single pass. Base classes live in core at `app/models/manageiq/providers/inventory/persister/builder.rb` and `lib/manageiq/providers/inventory/persister/`.

## Event collection

The `EventCatcher::Runner` subclass streams events from the provider and feeds them to core. It must implement:

| Method | Responsibility |
|---|---|
| `monitor_events` | Open the provider event stream; push raw events onto `@queue` or call `process_event` directly |
| `stop_event_monitor` | Shut down the event stream connection |
| `queue_event(event)` | Convert the raw event to a hash and call `EmsEvent.add_queue("add", @ems.id, event_hash)` |
| `filtered?(event)` | (optional) Return `true` to drop an event before queuing |
| `event_dedup_key(event)` † | Key used for flood-prevention deduplication |
| `event_dedup_descriptor(event)` † | Human-readable event description for flood-prevention logging |

† Only required when the `:flooding_monitor_enabled` setting is `true`. Currently only VMware implements the flooding monitor.

The event hash must include `:event_type` and any resource references (`vm_ems_ref`, `host_ems_ref`, etc.) so core can correlate the event to existing inventory. Event groups for policy and alerting are declared in the provider's settings YAML under `ems.<provider_key>.event_handling.event_groups`.

## Metrics collection

The `MetricsCapture` class (one per provider, inheriting from `ManageIQ::Providers::<ManagerType>::MetricsCapture`) handles C&U data collection. It must implement:

| Method | Responsibility |
|---|---|
| `perf_collect_metrics(interval_name, start_time, end_time)` | Fetch raw metrics from the provider; return `[counters_by_ems_ref, counter_values_by_ems_ref_and_ts]` |
| `capture_ems_targets(options = {})` | Return the objects (`Host`, `Vm`, `Storage`, etc.) eligible for capture |

Core processes the returned data into `Metric` records (realtime) and `MetricRollup` records (hourly/daily). Resources must declare `supports :capture` to be included in targeting.

## Operations

Provider operations (power actions, resize, snapshot, etc.) are dispatched as `MiqQueue` messages with role `ems_operations` and routed to the provider's `OperationsWorker` via `queue_name_for_ems_operations`. The pattern for each operation is:

1. Declare support with `supports :operation_name` (or `supports(:operation_name) { reason_unsupported }`) on the model.
2. Implement `raw_<operation>` on the model to make the actual provider API call; raise `NotImplementedError` in the base class to require provider implementation.
3. The `<operation>_queue` wrapper (provided by core mixins) enqueues the `raw_<operation>` call via `run_command_via_queue`.

Override `queue_name_for_ems_operations` on the manager class to return the provider-specific queue name (defaults to `"generic"` until an `OperationsWorker` is defined).

## Workers

Each worker is a separate OS process — a `MiqWorker` subclass. Do not use background threads. Worker base classes live in core.

| Worker | Core base class | Purpose |
|---|---|---|
| `RefreshWorker` | `ManageIQ::Providers::BaseManager::RefreshWorker` | Polls for full and targeted inventory refreshes |
| `EventCatcher` | `ManageIQ::Providers::BaseManager::EventCatcher` | Streams real-time events from the provider; creates `EmsEvent` records |
| `MetricsCollectorWorker` | `ManageIQ::Providers::BaseManager::MetricsCollectorWorker` | Collects performance metrics; feeds `Metric` records |
| `OperationsWorker` | `ManageIQ::Providers::BaseManager::OperationsWorker` | Executes provider operations queued with role `ems_operations` |

Each worker has a `Runner` inner class that contains the process loop. Workers are registered with systemd via `.service` / `.target` units in the `systemd/` directory of the plugin gem.

## VCR cassettes

HTTP interactions with the provider API are recorded as cassettes and replayed in specs. The configuration is strict — see `spec/manageiq/docs/agents/testing.md` for the full rules.

Provider-specific setup:

- Cassettes live in `spec/vcr_cassettes/`.
- Credentials and other secrets used as cassette placeholders are declared in `spec/config/secrets.defaults.yml` (committed, contains only placeholder names) and `spec/config/secrets.yml` (gitignored, contains real values for recording).
- Placeholders are registered via `VcrSecrets.define_all_cassette_placeholders` in `spec/spec_helper.rb`.

To re-record a cassette, delete the cassette file and re-run the spec with real credentials in `spec/config/secrets.yml`. VCR will record a new cassette on the next run.

## spec/models layout

Provider specs that exercise model classes go under `spec/models/<plugin_path>/`, mirroring the `app/models/<plugin_path>/` tree.

## Factories

- **Core** (`manageiq/spec/factories/`) — factories shared across providers or needed by core specs. Examples: `:ems_infra`, `:vm_or_template`, `:vm_cloud`.
- **Provider** (`spec/factories/`) — factories for models specific to that one provider.

Rule of thumb: if any spec outside this plugin would ever need the factory, define it in core.
