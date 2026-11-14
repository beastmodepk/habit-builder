# Commit conventions

Conventional Commits, one logical change per commit. The history is meant to
be read and reviewed commit by commit.

## Types

| Type | Use |
|---|---|
| `feat:` | a new feature or capability |
| `fix:` | a bug fix |
| `bug:` | a bug report / reproduction landed before its fix (docs or failing test) |
| `test:` | tests only |
| `docs:` | documentation only |
| `chore:` | project scaffolding, tooling, housekeeping |
| `refactor:` | behaviour-preserving restructuring |
| `style:` | visual / formatting changes with no behaviour change |

Format: `type(scope): short summary`, e.g. `feat(urge): add 10-minute urge timer`.

## Additions log

Every addition is recorded as the next numbered entry in
`docs/ADDITIONS-LOG.md`, in the same commit that adds it. Never renumber or
delete entries.

## Releases

Annotated tags mark milestones: `v0.1.0` = MVP. Future releases increment
semver and get a `CHANGELOG.md` entry.
