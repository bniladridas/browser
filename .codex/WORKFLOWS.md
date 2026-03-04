# Codex Workflows

Use this file for repeatable Codex-assisted tasks and checklists.

## Update README

- Edit the relevant section.
- Scan for broken links.
- Keep examples up to date.

## Repo Checklist

- Verify Flutter version requirement and any platform-specific notes.
- Run `./check.sh` if code changes touch build, test, or formatting.
- Avoid committing `.env` or secrets.
- Keep generated files out of hand-edited diffs.

## GitHub Operations (Local)

- Run GitHub commands locally if this sandbox lacks network access.
- Typical commands:
  - `git push`
  - `gh pr create`
  - `gh pr merge`

## PR Impact Validation (Required)

- Before running `gh pr create` or `gh pr edit`, review `## Impact`.
- Check only categories directly supported by `## Summary` bullets.
- If a box cannot be justified from `## Summary`, uncheck it.
- Re-run this validation after any PR description update.

## Version Bump (Manual)

- Update `VERSION` to `X.Y.Z+N`.
- Run `./scripts/pubspec.sh`.
- Commit with `chore: bump version to X.Y.Z`.
- Create PR titled `chore: bump version to X.Y.Z`.
- Tag release `desktop/app-X.Y.Z` and title `Release X.Y.Z`.
