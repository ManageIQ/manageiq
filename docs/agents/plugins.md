# Plugin Development

This document covers the structure and conventions for ManageIQ plugin gems — gems loaded as Rails engines that extend core functionality. Plugins are not standalone applications; they run mounted inside the core ManageIQ repository (checked out at `spec/manageiq/`), which provides all core models, workers, RBAC, settings, and helpers. The plugin only defines what it adds or overrides on top of core. Provider plugins have additional conventions; see [`provider_plugins.md`](provider_plugins.md).

## Available plugins

### Core plugins

| Plugin | Purpose |
|---|---|
| [`manageiq-api`](https://github.com/ManageIQ/manageiq-api) | REST API layer (JSON-API); changes to API endpoints belong here |
| [`manageiq-automation_engine`](https://github.com/ManageIQ/manageiq-automation_engine) | Automate Engine — event-driven automation, state machines, and method execution |
| [`manageiq-consumption`](https://github.com/ManageIQ/manageiq-consumption) | Chargeback / showback — cost allocation models and reporting |
| [`manageiq-content`](https://github.com/ManageIQ/manageiq-content) | Seed data: default automate domains, reports, roles, scan profiles, etc. |
| [`manageiq-decorators`](https://github.com/ManageIQ/manageiq-decorators) | View decorators shared between the UI and API |
| [`manageiq-schema`](https://github.com/ManageIQ/manageiq-schema) | Database migrations and schema definitions shared across the application |
| [`manageiq-ui-classic`](https://github.com/ManageIQ/manageiq-ui-classic) | Rails engine delivering the classic (PatternFly/jQuery) web UI; controller code lives here |

### Fundamental provider plugins

These behave less like external-system connectors and more like built-in platform capabilities:

| Plugin | Purpose |
|---|---|
| [`manageiq-providers-embedded_terraform`](https://github.com/ManageIQ/manageiq-providers-embedded_terraform) | Embedded Terraform runner — executes Terraform templates as a service; provides the `EmbeddedTerraform` manager and related workers directly within the platform |
| [`manageiq-providers-workflows`](https://github.com/ManageIQ/manageiq-providers-workflows) | Embedded Workflows engine (based on AWS States Language / Floe); provides the `Workflows` manager that orchestrates multi-step automation workflows natively in the platform |

### External-system provider plugins

`manageiq-providers-<provider_name>` gems implement the inventory/events/metrics/operations pipeline for a specific external system. They follow the standard provider structure described in [`provider_plugins.md`](provider_plugins.md). See [all provider plugins](https://github.com/ManageIQ?q=manageiq-providers-) for the full list.

### Non-plugin repositories

These repositories are part of the ManageIQ ecosystem but are **not** Rails engines and are not loaded as plugins:

| Repository | Kind | Purpose |
|---|---|---|
| [`manageiq-gems-pending`](https://github.com/ManageIQ/manageiq-gems-pending) | Ruby gem | Low-level utilities extracted from the old `gems/pending` directory — encoding, process helpers, XML, exceptions, etc. Declared directly in `Gemfile`; not a Rails engine. |
| [`manageiq-ui-service`](https://github.com/ManageIQ/manageiq-ui-service) | JavaScript app | Self-service portal UI (AngularJS/PatternFly). Standalone Node.js application; communicates with `manageiq-api` over REST. Has no presence in this repo's `Gemfile`. |

## Repo layout

```
app/          # Models, helpers, and other Rails autoloaded code (if any)
config/       # settings.yml (plugin-specific defaults) and secrets.defaults.yml
lib/          # Engine definition, rake tasks, and version file
locale/       # Gettext translation catalogs
spec/
  factories/  # FactoryBot factories for this plugin's models
  manageiq/   # Full copy / symlink of the core ManageIQ app — never edit here
  support/    # Shared spec helpers for this plugin
  *_spec.rb   # Specs
```

`spec/manageiq` is populated by `bin/setup` — either cloned from GitHub or symlinked from a local checkout via the `$MANAGEIQ_REPO` environment variable. It is excluded from RuboCop, yamllint, and the RSpec run (see `.rspec` and `.yamllint`).

## Setup and update

```bash
# Clone/symlink core and initialise the database
bin/setup

# Update dependencies and run any plugin-specific update steps.
# Also pulls the latest core manageiq if spec/manageiq is a clone (not a symlink).
bin/update
```

## Commands

```bash
# Run all specs
bundle exec rake

# Run a single spec file or example
bundle exec rspec spec/models/my_model_spec.rb
bundle exec rspec spec/models/my_model_spec.rb:42

# Lint
bundle exec rubocop
bundle exec haml-lint app/
bundle exec yamllint .
```

## Gemfile structure

The plugin `Gemfile` delegates almost everything to core:

```ruby
gemspec
eval_gemfile(File.expand_path("spec/manageiq/Gemfile", __dir__))
```

Runtime and development dependencies are declared in the `.gemspec`. Plugin-specific bundler overrides go in `bundler.d/` (gitignored except for `.keep`).

## Engine and settings

- The Rails engine is defined in `lib/<plugin_path>/engine.rb`.
- Plugin-specific `Settings` defaults live in `config/settings.yml` and are merged into the global `Settings` tree at boot.
- Read `Settings` at call time; never cache in a constant. Persist via `Vmdb::Settings.save!`. See `spec/manageiq/docs/agents/architecture.md`.

## Code style and conventions

All core conventions apply — see `spec/manageiq/AGENTS.md` and the docs it references. Plugin-specific notes:

- Plugins can bring their own UI (custom button forms, menu structures, pages), but prefer application-agnostic implementations first — provider/plugin-specific UI should only be added when a generic solution isn't feasible. API changes go in `manageiq-api`.
- Plugin factories belong in `spec/factories/`.
- Plugin shared spec helpers belong in `spec/support/`.
- i18n: user-visible strings use `_()` / `n_()`.

## Factories

Plugin factories belong in `spec/factories/`. For the non-obvious rules around what belongs in core vs. a provider plugin, see the [Factories section in `provider_plugins.md`](provider_plugins.md#factories).
