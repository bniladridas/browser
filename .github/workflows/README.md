# GitHub Workflows

Workflow files in this directory use a shared layout:

- SPDX license header first.
- YAML document marker (`---`) second.
- Short workflow name and focused job names.
- Repository-owner guards for automation that should only run in this repository.
- Browser GitHub App tokens for automation that writes to pull requests, issues, projects, or refs.

Workflow groups:

- `flutter.yml`, `ui-test.yml`, and `e2e.yml` run the main Flutter checks.
- `lint.yml` and `pr-title-check.yml` keep repository formatting and PR metadata consistent.
- `auto-label.yml`, `label-sync.yml`, `close-stale-issues.yml`, `issue-similarity.yml`, and
  `project-board-sync.yml` handle issue and pull request automation.
- `nightly.yml`, `release.yml`, and `version-bump.yml` handle release automation.
- `browser.yml`, `cla.yml`, and `create-pr.yml` support repository-specific automation.

Use `yamllint .github/workflows` after changing workflow files.
