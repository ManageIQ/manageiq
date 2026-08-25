# Documentation

Public-facing ManageIQ documentation is maintained in a dedicated repository separate from the application source.

## Documentation repository

| Repository | Purpose |
|---|---|
| [`manageiq-documentation`](https://github.com/ManageIQ/manageiq-documentation) | Source for all public ManageIQ docs — installation guides, user guides, API reference, and release notes. Written in Markdown and published to the ManageIQ docs site. |

## Scope

- User-facing feature documentation, installation guides, and how-to articles belong in `manageiq-documentation`, not in this repository.
- Code-level documentation (RDoc / YARD comments, `AGENTS.md`, `docs/agents/`) lives here alongside the code.
- When implementing a new user-visible feature, consider whether `manageiq-documentation` needs a corresponding update.
