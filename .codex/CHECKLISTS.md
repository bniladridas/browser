# Checklists

## Build and Test

- Run `./check.sh` for checks.
- Build desktop app with `flutter build macos`.
- Avoid committing `.env` or secrets.

## Docs Updates

- Keep examples current.
- Scan for broken links.
- Keep instructions consistent with scripts and workflows.

## Release Prep

- Bump `VERSION` to `X.Y.Z+N`.
- Run `./scripts/pubspec.sh`.
- Commit with `chore: bump version to X.Y.Z`.
- Tag release `desktop/app-X.Y.Z`.
- Title release `Release X.Y.Z`.
