---
description: Resubmit the retryable failures in a project, respecting the retry cap
---

Apply the retry policy in one pass over the project (argument: `$ARGUMENTS`,
default: current directory). **Dry-run by default** — list what would be
submitted and stop, unless the user said to go ahead in this message.

1. `espresso status "$ARGUMENTS" --json --needs-action`
2. For each `RETRY` row whose `budget_exhausted` is false, state the job dir,
   the signature, and the exact `sbatch` line you would run with the remedy
   applied.
3. Skip and list separately:
   - `budget_exhausted: true` — the 5-resubmit cap is spent; these need a human
     regardless of class.
   - `HUMAN` rows — say what the documented fix is; do not apply it here.
   - Anything that has already failed twice for the same reason, per the
     existing rule in the dft skill.
   - Ignored rows: paths listed under `## Ignored jobs` in
     `<project>/CLAUDE.md`, or under a listed prefix. The user chose not to
     finish these; resubmit only when they ask for one by name.
4. On the user's go-ahead, submit, then `espresso status record <dir> --jobid
   <id> --outcome RETRY` for each, so the budget is actually spent.

Never resubmit an unchanged input that has already failed twice for the same
reason without saying so and proposing a real change.
