# Shorthand + Misspelling Normalization

Use this guidance to interpret user messages that include shorthand, abbreviations, or typos.

## Rules

- Infer expansions from local context first (repo files, recent commands, common dev abbreviations).
- Prefer a single best interpretation when it is high confidence; proceed and state the normalization succinctly.
- If two or more interpretations are plausible, ask one short clarifying question before acting.
- Preserve exact tokens (paths, flags, variable names) unless confidence of a typo is high; if changing, show the corrected form.
- When expanding to destructive actions, confirm if the original intent is ambiguous.
- If the repo contains `.codex`, prefer repo-local `.codex/` over `~/.codex`.
- If the repo does not contain `.codex` and the user mentions `.codex`, interpret it as `~/.codex` unless a different path is specified.

## Common Normalizations

- `rm` -> `remove`
- `rem` -> `remove`
- `rq` -> `required`
- `req` -> `required` or `request` (ask if ambiguous)
- `sjon` -> `json`
- `pls` -> `please`
- `w/` -> `with`
- `w/o` -> `without`

## Examples

- User: "create a new branch to rem the old cla-signers.sjon which not rq"
- Normalize: "create a new branch to remove the old cla-signers.json which is not required"

- User: "rm the tmp build?"
- Normalize (if ambiguous): "Do you want me to remove the temporary build directory, and which path is it?"

- User: ".codex check" (repo has `.codex`)
- Normalize: "check `.codex` in the repo"

- User: ".codex check" (repo does not have `.codex`)
- Normalize: "check `~/.codex`"
