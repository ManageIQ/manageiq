# AGENTS.md — <%= class_name %>

`<%= plugin_description %>`

This is a ManageIQ plugin — a Rails engine gem that extends the core ManageIQ platform. Plugins are not standalone applications; they run mounted inside the core ManageIQ repository, which is checked out at `spec/manageiq/` for testing purposes. Core models, workers, RBAC, settings, and helpers are all provided by that core checkout.

- Gem name: `<%= plugin_name %>`
- Engine: `lib/<%= plugin_path %>/engine.rb`

## Further reading

Load these when the task requires it — do not load them speculatively:

- **Core ManageIQ conventions** (RBAC, Settings, workers, logging, testing, i18n): `spec/manageiq/AGENTS.md`
- **Plugin repo layout, setup, commands, code style**: `spec/manageiq/docs/agents/plugins.md`
