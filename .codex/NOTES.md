# Codex Notes

Use this file to capture project-specific context for Codex, such as:

- Architecture overviews
- Key conventions or guardrails
- Decisions and their rationale
- Known gotchas or edge cases

Keep entries short and dated when useful.

## Conventions

- Prefer small, focused PRs with clear titles and summaries.
- Follow PR title format: `type[scope] :: description`.
- Follow commit format: `type(scope): description` or `type[scope]: description`.
- Do not bypass hooks (no `--no-verify`).
- Keep docs concise and action-oriented.

## Do / Don't

Do:
- Use `rg` for fast searches.
- Keep changes scoped to the request.
- Add brief, helpful comments only when logic is non-obvious.

Don't:
- Revert unrelated local changes.
- Use destructive git commands unless explicitly requested.
- Add Codex-only guidance outside `.codex/` unless asked.

## Decision Log

- 2026-02-03: Added `.codex/` as a committed directory to centralize Codex guidance and templates.
