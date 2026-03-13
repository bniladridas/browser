# OpenCode Configuration

This directory contains configuration files for development workflow automation.

## Structure

```
.opencode/
├── config.yaml          # Main configuration file
├── hooks/
│   ├── pre-commit.sh    # Pre-commit hook script
│   └── create-pr.sh     # PR creation script
├── templates/
│   └── pr-description.md # PR description template
└── README.md            # This file
```

## Configuration

The `config.yaml` file contains:

- **Commit message rules**: Format, length limits, prohibited words
- **PR title rules**: Format, validation, prohibited words
- **PR description template**: Sections and structure
- **Interactive prompts**: User-friendly input prompts
- **Validation settings**: Word boundary matching configuration

## Usage

### Create a PR

Run the PR creation script:

```bash
./.opencode/hooks/create-pr.sh
```

This script will:
1. Prompt for your PR title interactively
2. Validate the title format and content
3. Create the PR using the template

### Manual PR Creation

If you prefer to create PRs manually, use this format:

```bash
gh pr create \
    --base main \
    --head <your-branch> \
    --title "type[scope] :: description" \
    --body-file .opencode/templates/pr-description.md
```

## Configuration Reference

### Commit Messages

- **Format**: `type: description`
- **Max first line**: 40 characters
- **Lowercase**: Required
- **Prohibited words**: `add` (use alternatives: integrate, implement, include, etc.)

### PR Titles

- **Format**: `type[scope] :: description`
- **Prohibited words**: `add` (use alternatives: integrate, implement, include, etc.)

### Validation

All validation uses whole-word matching (`grep -iw`) to avoid false positives:
- "address" does NOT match "add"
- "padding" does NOT match "add"
- "added" does NOT match "add"

## Notes

- This configuration is optional and can be used alongside `AGENTS.md`
- `AGENTS.md` remains the primary documentation for development guidelines
- These scripts provide automation for common tasks
