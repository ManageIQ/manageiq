# Testing

## RSpec setup

- Tests run with `--order random`. Caches are reset between examples via `EvmSpecHelper.clear_caches`.
- `MiqRegion.seed` runs before the suite — tests can assume a default region exists.
- `EvmSpecHelper.local_miq_server` creates/finds a local server record; use it when a test needs server role assignment.
- Specs that create DB rows must use `use_transactional_fixtures` isolation — avoid shared mutable state at class level in specs. `parallel_tests` can be configured locally to speed up the suite but is not used by CI.

## FactoryBot

Factory files live in `spec/factories/`. Use `FactoryBot.create(:factory_name)` patterns. When adding a sequence-based name attribute to a factory, use the `seq_padded_for_sorting(n)` helper, which pads to 13 digits for consistent sort ordering.

## VCR cassettes

Cassettes live in `spec/vcr_cassettes/`. The configuration is strict:

- `allow_http_connections_when_no_cassette: false` — all outbound HTTP in specs must be cassette-recorded or explicitly stubbed.
- `allow_unused_http_interactions: false` — cassettes with interactions that are never replayed will fail the spec.

## Spec helpers

Key helpers in `spec/support/`:

| Helper | Purpose |
|---|---|
| `evm_spec_helper.rb` | Suite-wide setup, cache clearing, `local_miq_server` |
| `settings_helper.rb` | `stub_settings(hash)`, `stub_settings_merge(hash)` |
| `supports_helper.rb` | `stub_supports`, `stub_supports_not` for feature support flags |

Check these before assuming standard RSpec helpers cover a given concern.

## CI test suites

CI runs two suites, controlled by the `TEST_SUITE` env var:

- `TEST_SUITE=vmdb` — full spec suite (`bundle exec rake test:vmdb`)
- `TEST_SUITE=security` — security audit suite (`bundle exec rake test:security`)
