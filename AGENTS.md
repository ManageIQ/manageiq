# AGENTS.md

This file provides guidance to agents working in this repository.

## Product

ManageIQ is an open source hybrid-cloud management platform — a single management plane for virtual, cloud, container, and physical infrastructure. Provider workers collect inventory/events/metrics from external systems into PostgreSQL (VMDB); all other features (RBAC, reporting, policy, automation, service catalog) operate on that normalized data. Operations are posted back to the native provider.

Key domains: resource management, tagging, dashboards, reporting, chargeback, service catalog, policy (event-condition-action), automation (Automate Engine, Embedded Ansible, Embedded Terraform, Embedded Workflows), and auth/RBAC with multi-tenancy.

See [`docs/agents/product.md`](docs/agents/product.md) when you need model names, feature details, or deployment topology.

## Stack

Ruby on Rails monolith (no frontend — controllers live in plugins/engines, not `app/controllers/`). Ruby 3.3.x required. PostgreSQL 16. The default integration branch is `master`.

## Terminology

- **VMDB** (Virtual Machine DataBase) — legacy name for the core ManageIQ database/application layer. Appears throughout the codebase in class names, rake tasks, and log prefixes.
- **EVM** (Enterprise Virtualization Manager) — even older term for the same application layer as VMDB (e.g. `EvmSpecHelper`, `evm.rake`).
- **C&U** (Capacity & Utilization) — the metrics collection, rollup, and reporting subsystem.

## Commands

```bash
# Run all specs (equivalent to what CI runs)
bundle exec rake

# Run a single spec file / example
bundle exec rspec spec/models/vm_or_template_spec.rb
bundle exec rspec spec/models/vm_or_template_spec.rb:42

# Lint
bundle exec rubocop
bundle exec haml-lint app/
bundle exec yamllint .

# Security suite
bundle exec rake test:security

# Dev environment bootstrap (SKIP_DATABASE_SETUP, SKIP_UI_UPDATE, SKIP_TEST_RESET)
bin/setup
```

## Code Style

- RuboCop inherits from `manageiq-style` gem; local overrides in `.rubocop_local.yml`. Do not edit `.rubocop.yml`.
- Global logger variables (`$log`, `$audit_log`, etc.) are the project standard — see `.rubocop_local.yml` for the full list. `Rails.logger` is acceptable only for the Rails production/development log.
- Internationalization uses FastGettext/Gettext (`_`, `n_`, `N_`). Translate the literal string first, then interpolate named placeholders. See [`docs/agents/coding.md`](docs/agents/coding.md).
- HAML: line length max 160, `SpaceInsideHashAttributes: no_space`.
- YAML: `indent-sequences: false`.

## Architecture

Key non-obvious constraints — read [`docs/agents/architecture.md`](docs/agents/architecture.md) before making structural changes:

- **ID regions**: model IDs are region-scoped; never assume global uniqueness.
- **RBAC**: use `Rbac.search` / `Rbac.filtered`, never raw `.where`, for user-facing queries.
- **Settings**: read `Settings` at call time; persist via `Vmdb::Settings.save!` or `resource.add_settings_for_resource`.
- **Workers**: `MiqWorker` subclasses are separate OS processes — no background threads in models.
- **No HTTP/view/API layer here**: UI changes go in `manageiq-ui-classic`, API changes in `manageiq-api`.

## Testing

Tests use random order, transactional fixtures, and strict VCR. See [`docs/agents/testing.md`](docs/agents/testing.md) before writing or modifying specs.

## Plugins / Engines

- Plugin gems are loaded as Rails engines; engine factories are auto-added to FactoryBot.
- Add plugin gems via `manageiq_plugin "plugin-name"` in the `Gemfile`.
- On release branches (non-`master`), `Gemfile.lock.release` pins gem versions. If changing gems on a release branch, update both lockfiles.
- See [`docs/agents/plugins.md`](docs/agents/plugins.md) for available plugins and development conventions.

## Further reading

Load these when the task requires it — do not load them speculatively:

- **Product features / model names**: [`docs/agents/product.md`](docs/agents/product.md) — providers, resource management, service catalog, policy, automation, RBAC, deployment
- **Making code changes**: [`docs/agents/coding.md`](docs/agents/coding.md) — non-obvious patterns, loggers, RuboCop, factory helpers
- **Architecture / design questions**: [`docs/agents/architecture.md`](docs/agents/architecture.md) — RBAC, Settings, ID regions, workers, plugin model
- **Working with RBAC or authorization**: [`docs/agents/rbac.md`](docs/agents/rbac.md) — data model, filter types, tenancy, feature flags, spec helpers
- **Writing or modifying specs**: [`docs/agents/testing.md`](docs/agents/testing.md) — RSpec setup, FactoryBot, VCR, spec helpers
- **Working in a plugin gem**: [`docs/agents/plugins.md`](docs/agents/plugins.md) — repo layout, bin/setup, engine, settings, spec structure
- **Working in a provider plugin**: [`docs/agents/provider_plugins.md`](docs/agents/provider_plugins.md) — manager model, inventory pipeline, event collection, metrics collection, operations, workers, VCR cassettes
- **Build and packaging**: [`docs/agents/build.md`](docs/agents/build.md) — RPM build, appliance images, container/pod deployment, release branches
- **Public documentation**: [`docs/agents/documentation.md`](docs/agents/documentation.md) — manageiq-documentation repo, user guides, when to update docs
