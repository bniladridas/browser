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
