# PR Review Suggestions

Store PR review suggestions here as JSON files.

## Format

```json
{
  "id": "unique-id",
  "source": "PR #208",
  "date": "2026-02-07",
  "description": "Brief description of the suggestion",
  "file": "lib/logging/network_monitor.dart",
  "line": 51,
  "applied": false,
  "applied_date": null
}
```

## Usage

1. When receiving a code review suggestion, save it here
2. Mark `applied: true` when fixed
3. Use this to track all suggestions and their status
