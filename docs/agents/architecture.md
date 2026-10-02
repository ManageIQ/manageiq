# Architecture

## ID regions

Every model ID is region-scoped via `ActiveRecord::IdRegions`. Records in different regions have IDs in non-overlapping numeric ranges — never assume IDs are globally unique across the database. Cross-region associations are by design. ID region assignment is set at record creation and cannot be changed.

## RBAC

RBAC is enforced by `Rbac::Filterer` (`lib/rbac/filterer.rb`) — it is **not** automatic. Use `Rbac.search` or `Rbac.filtered` instead of raw `.where` for any user-facing record retrieval. See [`rbac.md`](rbac.md) for the full reference (data model, filter types, tenancy strategy, feature flags, and spec helpers).

Key non-obvious rules:

- For tag-based RBAC to apply to a class, add it to both `Rbac::Filterer::CLASSES_THAT_PARTICIPATE_IN_RBAC` and ensure the model includes `acts_as_miq_taggable`.
- Belongsto filters force Ruby-side filtering — SQL `LIMIT` cannot be applied when they are active.
- Tenant access strategy (which tenants can see which resources) is defined per-model in `TENANT_ACCESS_STRATEGY` in `Rbac::Filterer`.

## Settings

`Settings` is a live `Config::Options` tree managed by `lib/vmdb/settings.rb` — it is not a static hash or Rails config.

- **Read**: access `Settings` directly at call time. Do not cache values in class-level constants — settings are hot-reloadable at runtime.
- **Persist** (production code): use `Vmdb::Settings.save!(resource, hash)` or the model-level convenience `resource.add_settings_for_resource(hash)` (available on models that include `ConfigurationManagementMixin`). Do not assign to `Settings` directly.
- **Stub** (specs): use `stub_settings(hash)` or `stub_settings_merge(hash)` from `spec/support/settings_helper.rb`.

## Workers

Each worker type is a subclass of `MiqWorker` and runs as a separate OS process — not a thread. Do not use background threads in models. Start individual workers in development via:

```bash
lib/workers/bin/run_single_worker.rb <WorkerClassName>
```

Architecture must not rely on in-process shared state between workers.

## Queue

As ManageIQ is a distributed and scalable product a queue system is used to distribute work to the various workers.  There are at present two queue backend types used:

- **MiqQueue**: A database backed work distribution system
- **Kafka**: A highly scalable event streaming platform

### MiqQueue

MiqQueue is the queue system used by ManageIQ from the beginning.  It uses a table called `miq_queue` and combined with a number of columns (`queue_name`, `class_name`, `instance_id`, `args`, `zone`, and `role`) is used by Queue workers to get their work items.

The MiqQueue interface is simple: `MiqQueue.put` and `MiqQueue.get` form the core of the MiqQueue interface and are used for submitting work for a worker and for a worker to dequeue a work item respectively.
Additionally there are some methods which are specific to `MiqQueue` and are not commonly provided by standard queue systems: `put_or_update`, `put_unless_exists`, and `unqueue`.  New invocations of these methods should be avoided at all cost as they make it more difficult to move to a more standard queue backend.

### Kafka

Kafka is a highly scalable event streaming system, allowing for both "queue" and "topic" modes based on the configuration of broadcast groups.

In "queue" mode it operates similar to `MiqQueue` where multiple workers can be listening to a queue but only 1 will receive the message.
In "topic" mode all workers listening to a queue will receive a message published to the queue.

Currently ManageIQ uses kafka for the ems_events topic, so calls to `EmsEvent.add_queue` will publish the event to a kafka topic if kafka is configured.

## Plugin / provider model

Provider code (AWS, VMware, OpenStack, etc.) lives in separate gems (e.g. `manageiq-providers-vmware`) loaded as Rails engines at boot. Core models define abstract base classes (e.g. `ExtManagementSystem`, `VmOrTemplate`); providers subclass them. New features added to base classes automatically propagate to all providers.

Add plugin gems via the `manageiq_plugin "plugin-name"` helper in the `Gemfile`.

## Internationalization

ManageIQ uses **FastGettext/Gettext** for translations — not the standard Rails i18n (`I18n.t`) system. A very small portion of the codebase does use Rails i18n, but the overwhelming convention is the Gettext helpers (`_`, `n_`, `N_`). See [`docs/agents/coding.md`](coding.md) for usage details.

## No HTTP / view / API layer in this repo

This repo is a backend model/service layer. There is no `app/controllers/` or `app/views/`. Any work touching API endpoints, views, or controller logic requires changes in separate repos:

- UI: [`manageiq-ui-classic`](https://github.com/ManageIQ/manageiq-ui-classic)
- REST API: [`manageiq-api`](https://github.com/ManageIQ/manageiq-api)
