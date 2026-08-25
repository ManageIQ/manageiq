# Coding

## Non-obvious patterns

- **No `app/controllers/`** — this repo is a model/service layer. Controller code lives in plugin engines. See [`docs/agents/architecture.md`](architecture.md) for details.
- **`Rbac.search` / `Rbac.filtered`** instead of raw `.where` for any user-facing record retrieval. See [`docs/agents/architecture.md`](architecture.md) for the full RBAC requirements.
- **ID regions**: all model IDs are region-scoped. Never assume IDs are globally unique across the database. See [`docs/agents/architecture.md`](architecture.md).
- **Settings**: do not assign to `Settings` directly — use `Vmdb::Settings.save!` or `add_settings_for_resource`. See [`docs/agents/architecture.md`](architecture.md) for the full Settings API.
- **Global loggers**: the project uses global logger variables (`$log`, `$audit_log`, etc.) for application-level logging — see `.rubocop_local.yml` for the full allowed list. Plugin gems define their own additional loggers. `Rails.logger` is acceptable when specifically targeting the Rails production/development log.
- **Worker isolation**: each worker type is a subclass of `MiqWorker` running as a separate OS process. Do not use background threads in models.
- **RuboCop base config** comes from the `manageiq-style` gem. Run `bundle exec rubocop` to validate. Do not edit `.rubocop.yml` — use `.rubocop_local.yml` for local overrides.
- **Factories use padded sequences**: use `seq_padded_for_sorting(n)` when adding sequence-based name attributes to factories. See [`docs/agents/testing.md`](testing.md).
- **VCR cassettes are strict**: all HTTP in specs must be cassette-recorded or explicitly stubbed. See [`docs/agents/testing.md`](testing.md).

## Internationalization

- Use FastGettext/Gettext helpers for user-visible strings: `_` for simple strings, `n_` for plurals, and `N_` when a string must be marked for translation now but translated later. See existing usage throughout `app/` and [`lib/postponed_translation.rb`](../../lib/postponed_translation.rb).
- Translate the literal string first and then interpolate named placeholders, e.g. `_("...") % {:name => value}`. Do not build English strings with interpolation before translation.
- Locale discovery is filesystem-driven from `locale/` directories and optional plugin `config/supported_locales.yml` files. Human locale names come from [`config/human_locale_names.yaml`](../../config/human_locale_names.yaml) via [`Vmdb::FastGettextHelper`](../../lib/vmdb/fast_gettext_helper.rb).
