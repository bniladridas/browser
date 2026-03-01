# Agent Guidelines

## PR Title Style

Use the format: `type[scope] :: description`

- `type`: Conventional commit type (feat, fix, chore, etc.)
- `scope`: Feature area in brackets (e.g., [crashlytics], [firebase])
- `description`: Brief, imperative description

Examples:
- `feat[crashlytics] :: integrate Firebase Crashlytics for crash reporting`
- `chore[firebase] :: temporarily remove Firebase Crashlytics due to Flutter bug`
- `fix[ui] :: resolve button alignment issue`

This ensures consistent, readable PR titles for better tracking and automation.

## PR Description Template

Use the format:

## Summary
- Bullet point descriptions of changes

## Impact
Select applicable categories (use `[x]` for checked, `[ ]` for unchecked):
- [ ] New feature
- [ ] Bug fix
- [ ] Breaking change
- [ ] Build / CI
- [ ] Refactor / cleanup
- [ ] Documentation
- [ ] Tests
- [ ] Performance
- [ ] Security

## Related Items
- Resolves issues: #[issue-number]
- Closes PRs: #[pr-number]
- Resources: [PRs tab](../../pulls), [Issues tab](../../issues)

## Notes for reviewers
- Additional details or context

This ensures consistent, structured PR descriptions for clear communication and easy tracking of related items.

## Review Process

When reviewing PRs, document the review process used (e.g., self-review, peer review, automated review).

This ensures transparency and proper tracking of review activities.

## Release Template

Use the format for GitHub releases:

- **Tag**: `desktop/app-X.Y.Z` (where X.Y.Z is the version without +build number)
- **Title**: `Release X.Y.Z`
- **Notes**: Summarize the changes, including new features, fixes, and breaking changes. Use bullet points for clarity.

Example:
```
## What's New
- Added Firebase Crashlytics for crash reporting
- Improved UI responsiveness

## Bug Fixes
- Fixed button alignment issue

## Technical Changes
- Updated Podfile for better warnings handling
```

This ensures consistent, informative release notes.

## Commit Message Guidelines

Follow the repository's pre-commit hooks for commit messages:

- Use conventional commit format without scope punctuation: `type: description`
- Keep the first line lowercase
- Keep the first line concise (max 40 characters) to satisfy hook checks
- Examples:
  - `feat: add crashlytics integration`
  - `fix: resolve button alignment`

Agents must adhere to these rules to pass CI checks. Do not use --no-verify or bypass hooks; fix issues to ensure code quality.

## Issue Tracking During PR Work

When a PR addresses multiple distinct findings/fixes, create separate tracking issues and reference them in the PR description.

1. Create issue(s) using `gh issue create` (use clear tracking title + summary/body).
2. Update PR description with `gh pr edit` and include all issue numbers under:
   - `Resolves issues: #<issue1>, #<issue2>, ...`
3. Keep the PR summary aligned with the issue list so reviewers can trace each fix.

This keeps changes auditable and links each user-facing fix to an issue.

## Version Bump PR Template

When creating version bump PRs (e.g., `version-bump-X.Y.Z` branch):

1. Get the PR number from the branch name or the automated version bump:
   ```bash
   gh pr list --head <branch-name> --json number,title
   ```

2. Find all PRs merged since the last version bump PR by checking `git log --oneline main` to identify PRs merged after the previous version bump PR (e.g., #240 for version-bump-1.2.4 -> #261).

3. Categorize changes using the release template format:
   - **What's New**: New features (feat PRs)
   - **Bug Fixes**: Fix PRs
   - **Documentation**: Docs and readme PRs
   - **Maintenance**: Chore PRs (licenses, cleanup)

4. Update the PR description:
   ```bash
   gh pr edit <pr-number> --body "$(cat <<'EOF'
   ## Summary
   - Automated version bump to X.Y.Z after merging PR #<previous-pr>

   ## What's New
   - #<pr-number> - <type>[<scope>]: <description>

   ## Bug Fixes
   - #<pr-number> - <type>[<scope>]: <description>

   ## Documentation
   - #<pr-number> - <type>[<scope>]: <description>

   ## Maintenance
   - #<pr-number> - <type>[<scope>]: <description>

   ## Impact
   - [ ] New feature
   - [ ] Bug fix
   - [ ] Breaking change
   - [x] Build / CI
   - [x] Refactor / cleanup
   - [x] Documentation
   - [ ] Tests
   - [ ] Performance
   - [ ] Security

   ## Related Items
   - Resolves issues: #<pr-number>
   - Merged PRs: #<pr1>, #<pr2>, ...

   ## Notes for reviewers
   - This is an automated version bump PR following the release template format.
   EOF
   )"
   ```

This ensures version bump PRs have high-quality descriptions that track all changes since the last release.

## Workflow Creation

When creating GitHub Actions workflows:

- Include SPDX license header at the top.
- Add document start `---` for YAML.
- Run `yamllint` to check syntax and formatting.
- Ensure lines are under 120 characters.
- Add a new line at the end of the file.

This ensures safe and valid workflow files.

## Firebase Setup

This project uses Firebase with environment variables. For local development:

1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Update `.env` with valid Firebase credentials from your Firebase project.

3. For macOS, create a dummy `GoogleService-Info.plist`:
   - Run `flutterfire configure --platforms=macos` to generate real config
   - Or create a dummy file at `macos/Runner/GoogleService-Info.plist`

**Warning**: If `.env` is not provided with correct Firebase variables, the macOS app will crash with:
```text
Exception Type: EXC_CRASH (SIGABRT)
Application Specific Information: abort() called
```

This is because Firebase tries to initialize with invalid configuration.

## Creating Pull Requests

Use the `gh pr create` command with the full PR body in HEREDOC format:

```bash
gh pr create \
  --base main \
  --head <branch-name> \
  --title "<pr-title>" \
  --body "$(cat <<'EOF'
## Summary
- Bullet point descriptions of changes

## Impact
- [ ] New feature
- [ ] Bug fix
- [ ] Breaking change
- [ ] Build / CI
- [ ] Refactor / cleanup
- [ ] Documentation
- [ ] Tests
- [ ] Performance
- [ ] Security

## Related Items
- Resolves issues: #[issue-number]
- Closes PRs: #[pr-number]
- Resources: [PRs tab](../../pulls), [Issues tab](../../issues)

## Notes for reviewers
- Additional details or context
EOF
)"
```

This ensures proper formatting with multiline body text.
