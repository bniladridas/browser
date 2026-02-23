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
- [x] Build / CI
- [x] Refactor / cleanup
- [x] Documentation

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

- Use conventional commit format: `type(scope): description` or `type[scope]: description`
- Keep the first line lowercase
- Examples:
  - `feat(firebase): add crashlytics integration`
  - `fix[ui]: resolve button alignment`

Agents must adhere to these rules to pass CI checks. Do not use --no-verify or bypass hooks; fix issues to ensure code quality.

## Workflow Creation

When creating GitHub Actions workflows:

- Include SPDX license header at the top.
- Add document start `---` for YAML.
- Run `yamllint` to check syntax and formatting.
- Ensure lines are under 120 characters.
- Add a new line at the end of the file.

This ensures safe and valid workflow files.
