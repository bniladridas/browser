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
Only mark items that are directly applicable to the PR. Do not pre-check categories by default.
- [ ] New feature
- [ ] Bug fix
- [ ] Breaking change
- [ ] Build / CI
- [ ] Refactor / cleanup
- [ ] Documentation
- [ ] Tests
- [ ] Performance
- [ ] Security

Impact validation rule (required):
- For every checked category, there must be at least one matching bullet in `## Summary`.
- If no concrete change supports a category, keep it unchecked.
- For version-bump PRs, `Build / CI` should be checked only when workflows/build tooling are changed in the PR.
- For version-bump PRs without CI/workflow changes, prefer `Refactor / cleanup` and/or `Documentation` when applicable.

## Related Items
- Resolves #<id>
- Closes: #[pr-number]
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
- NEVER use the word "add" in commit messages - Use alternative verbs like "integrate", "implement", "include", "attach", "configure", "setup", "enable", "support", etc.
- Examples:
  - `feat: add crashlytics integration` (NOT ALLOWED)
  - `feat: integrate crashlytics for crash reporting` (USE THIS INSTEAD)
  - `fix: add button alignment fix` (NOT ALLOWED)
  - `fix: resolve button alignment issue` (USE THIS INSTEAD)

Validation Rule: Before committing, verify the commit message does not contain the word "add" (case-insensitive). Use:
```bash
git log --oneline -1 | grep -qiw "add" && echo "ERROR: Commit message contains 'add'" || echo "OK"
```

Note: For robust handling of user input (e.g., PR titles), use `printf "%s\n" "$VAR" | grep -qiw "add"` instead of `echo "$VAR" | grep -qiw "add"` to avoid issues with input starting with hyphens.

Agents must adhere to these rules to pass CI checks. Do not use --no-verify or bypass hooks; fix issues to ensure code quality.

## Issue Tracking During PR Work

When a PR addresses multiple distinct findings/fixes, create separate tracking issues and reference them in the PR description.

1. Create issue(s) using `gh issue create` (use clear tracking title + summary/body).
2. Update PR description with `gh pr edit` and include all issue numbers under:
   - `Resolves #<issue1>, #<issue2>, ...`
3. Keep the PR summary aligned with the issue list so reviewers can trace each fix.

This keeps changes auditable and links each user-facing fix to an issue.

## Standard Delivery Flow

Use this sequence for normal feature/fix delivery:

1. Create a branch from `main` with a descriptive name (for example, `fix-...`, `feat-...`).
2. Create or identify the tracking issue with `gh issue create` (or existing issue).
3. Implement changes, run required checks, and commit using valid commit-message rules.
4. Push the branch to origin.
5. Create the PR with `gh pr create` using the template.
6. In PR `## Related Items`, include `Resolves #<id>` for the tracking issue.

This flow ensures each PR is traceable from branch to issue to merge.

## Issue and PR Reference Syntax

When referencing issues or PRs in PR descriptions, use GitHub auto-linking/auto-closing keywords.
Preferred forms:

- `Fixes #<id>`
- `Fix #<id>`
- `Fixed #<id>`

- `Closes #<id>`
- `Close #<id>`
- `Closed #<id>`

- `Resolves #<id>`
- `Resolve #<id>`
- `Resolved #<id>`

Do not use labels like `Closes PRs:` because they do not follow GitHub keyword syntax.
If GitHub linking is unavailable in a specific environment, add plain references as fallback.

## Version Bump PR Template

When creating version bump PRs (e.g., `version-bump-X.Y.Z` branch):

1. Get the PR number from the branch name or the automated version bump:
   ```bash
   gh pr list --head <branch-name> --json number,title
   ```

2. Find all PRs merged since the last version bump PR using merge timestamps (`mergedAt`), not PR number ordering. Include only PRs with `mergedAt` strictly later than the previous version bump PR's `mergedAt` (e.g., via `gh pr view <previous-version-pr> --json mergedAt` and `gh pr list --state merged --base main --json number,title,mergedAt`).

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
   - Mark only categories that are truly applicable to this specific version bump PR.
   - Apply the impact validation rule above before checking any box.
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
   - Resolves #<id>
   - Closes: #<pr-number>
   - Merged PRs: #<pr1>, #<pr2>, ...

   ## Notes for reviewers
   - This is an automated version bump PR following the release template format.
   EOF
   )"
   ```

This ensures version bump PRs have high-quality descriptions that track all changes since the last release.

## Version Bump Delivery Flow

Use this sequence for version bump work:

1. Start from `main` and pull latest changes.
2. Switch to the version bump branch (for example, `version-bump-X.Y.Z`) or create it if needed.
3. Run the project version bump script/process for that release target.
4. Validate generated version changes and run required checks.
5. Immediately after running the version bump script, normalize the `assets/whats_new.json` entry for the target release using `jq` (required step), for example:
   ```bash
   jq '.\"X.Y.Z\" = [\"<minimal release note sentence>\"]' assets/whats_new.json > /tmp/whats_new.json \
     && mv /tmp/whats_new.json assets/whats_new.json
   ```
6. Re-validate `VERSION`, `pubspec.yaml`, and `assets/whats_new.json` are in sync.
7. Commit and push the version bump branch.
8. Create or update the version bump PR using the template above.
9. Ensure PR `## Related Items` uses GitHub keyword syntax (`Resolves #<id>`, `Closes #<id>` as applicable).
10. Validate the `Merged PRs` list against `mergedAt` boundaries so PRs merged before the previous version bump are excluded.

This keeps release/version PRs repeatable and reviewable.

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
# Prompt for PR title interactively
read -p "Enter your PR title: " PR_TITLE

# Validate PR title does not contain "add"
if printf "%s\n" "$PR_TITLE" | grep -qiw "add"; then
  echo "ERROR: PR title contains 'add'. Use alternative verbs like integrate, implement, include, etc."
  exit 1
fi

gh pr create \
  --base main \
  --head <branch-name> \
  --title "$PR_TITLE" \
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
- Resolves #<id>
- Closes: #[pr-number]
- Resources: [PRs tab](../../pulls), [Issues tab](../../issues)

## Notes for reviewers
- Additional details or context

## Verification Steps

> [!NOTE]
> **Test word boundary matching**
> ```bash
> # Should match (contains standalone "add")
> printf "%s\n" "fix: add address handling" | grep -qiw "add" && echo "FOUND" || echo "NOT FOUND"
> 
> # Should NOT match (no standalone "add")
> printf "%s\n" "fix: integrate address handling" | grep -qiw "add" && echo "FOUND" || echo "NOT FOUND"
> 
> # Should NOT match (contains "padding" not "add")
> printf "%s\n" "fix: padding issue" | grep -qiw "add" && echo "FOUND" || echo "NOT FOUND"
> ```

> [!WARNING]
> **Verify commit message validation**
> ```bash
> # Test with prohibited word
> printf "%s\n" "feat: add crashlytics integration" | grep -qiw "add" && echo "ERROR: Contains 'add'" || echo "OK"
> 
> # Test with allowed alternative
> printf "%s\n" "feat: integrate crashlytics for crash reporting" | grep -qiw "add" && echo "ERROR: Contains 'add'" || echo "OK"
> ```

> [!TIP]
> **Verify PR title format**
> ```bash
> # This PR title (valid)
> printf "%s\n" "chore[guidelines] :: integrate commit message and pr title validation" | grep -E "^(feat|fix|docs|refactor|chore|deps|perf|ci|build|revert)\[[a-zA-Z0-9]+\]\ ::\ .+" && echo "Format valid" || echo "Format invalid"
> 
> # This would be invalid (contains "add")
> printf "%s\n" "chore[guidelines] :: add validation for pr titles" | grep -qiw "add" && echo "Contains prohibited word" || echo "OK"
> ```
EOF
)"
```

This ensures proper formatting with multiline body text and validates that PR titles do not contain "add" using word boundaries.
