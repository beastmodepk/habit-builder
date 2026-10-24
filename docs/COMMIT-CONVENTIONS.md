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

## Assisted-by trailer

Every commit in this repo carries an assistance trailer in the commit body:

```
Assisted-by: Muse Wonder
```

History stays honest about how the code was produced, whoever authors,
reviews, amends, or signs the commits afterwards.

## Releases

Annotated tags mark milestones: `v0.1.0` = MVP. Future releases increment
semver and get a `CHANGELOG.md` entry.
