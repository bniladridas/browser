# Manual Version Bump Process

If the automated version bump workflow fails (e.g., due to branch deletion or workflow issues), follow these steps to manually bump the version and create a release.

## Steps

1. **Update VERSION File**:
   - Edit `VERSION` to the new version (e.g., `1.0.2+1`).

2. **Update pubspec.yaml**:
   - Run `./scripts/pubspec.sh` to sync the version.

3. **Commit Changes**:
   - `git add VERSION pubspec.yaml`
   - `git commit -m "chore: bump version to X.Y.Z"` (where X.Y.Z is the version part, e.g., 1.0.2, excluding the +build number)

4. **Create Branch and PR**:
   - `git checkout -b version-bump-X.Y.Z` (use X.Y.Z without +build)
   - `git push origin version-bump-X.Y.Z`
   - Create a PR on GitHub with title "chore: bump version to X.Y.Z".

5. **Merge PR**:
   - Merge the PR to main.

6. **Create Tag and Release**:
   - `git tag desktop/app-X.Y.Z` (use X.Y.Z without +build)
   - `git push origin desktop/app-X.Y.Z`
   - On GitHub, go to Releases > Create new release with tag `desktop/app-X.Y.Z`, title "Release X.Y.Z", and notes summarizing the changes.

## Notes
- The automated workflow should handle this, but use this as a fallback.
- Ensure the tag prefix `desktop/app` matches the script configuration.
