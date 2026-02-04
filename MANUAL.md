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
 - Unsigned macOS builds will show Gatekeeper warnings for users.

## macOS Release Signing Prereqs
- Add GitHub Actions secret `MACOS_CERTIFICATE` (base64 .p12).
- Add GitHub Actions secret `MACOS_CERTIFICATE_PASSWORD`.
- Add GitHub Actions secret `MACOS_KEYCHAIN_PASSWORD`.
- Add GitHub Actions secret `MACOS_CODE_SIGN_IDENTITY`.
- Add GitHub Actions secret `APPLE_ID`.
- Add GitHub Actions secret `APPLE_TEAM_ID`.
- Add GitHub Actions secret `APPLE_APP_SPECIFIC_PASSWORD`.
- Add GitHub Actions secret `MACOS_APP_BUNDLE_ID`.
- The `MACOS_CODE_SIGN_IDENTITY` should be a Developer ID Application identity.
- The `MACOS_APP_BUNDLE_ID` should match the bundle ID you want to ship (not `com.example.browser`).

## Codex Quickstart

- Read `.codex/README.md` for the directory overview.
- Check `.codex/NOTES.md` for conventions and decisions.
- Use `.codex/WORKFLOWS.md` and `.codex/CHECKLISTS.md` for repeatable tasks.
