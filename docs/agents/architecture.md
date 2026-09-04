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

## Plugin / provider model

Provider code (AWS, VMware, OpenStack, etc.) lives in separate gems (e.g. `manageiq-providers-vmware`) loaded as Rails engines at boot. Core models define abstract base classes (e.g. `ExtManagementSystem`, `VmOrTemplate`); providers subclass them. New features added to base classes automatically propagate to all providers.

Add plugin gems via the `manageiq_plugin "plugin-name"` helper in the `Gemfile`.

## Internationalization

ManageIQ uses **FastGettext/Gettext** for translations — not the standard Rails i18n (`I18n.t`) system. A very small portion of the codebase does use Rails i18n, but the overwhelming convention is the Gettext helpers (`_`, `n_`, `N_`). See [`docs/agents/coding.md`](coding.md) for usage details.

## No HTTP / view / API layer in this repo

This repo is a backend model/service layer. There is no `app/controllers/` or `app/views/`. Any work touching API endpoints, views, or controller logic requires changes in separate repos:

- UI: [`manageiq-ui-classic`](https://github.com/ManageIQ/manageiq-ui-classic)
- REST API: [`manageiq-api`](https://github.com/ManageIQ/manageiq-api)
