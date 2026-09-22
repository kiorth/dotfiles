---
description: Check job status across a DFT project and act on the retry policy
---

Run `espresso status --json` for the project (argument: `$ARGUMENTS`, default:
the current project) and report what changed.

1. `espresso status "$ARGUMENTS" --json` — if no argument, run it in the current
   directory. The command is read-only and never submits.
2. Compare against `.espresso-status.json` to report **deltas since the last
   check**, not the whole tree. A 200-row project with three changes should
   produce a three-line report.
3. Apply the retry policy in `$WORK/CLAUDE.md`:
   - `RETRY` → resubmit with the remedy the JSON names, record it, do not ask.
   - `HUMAN` → attempt the documented fix from the `remedy` field **once**;
     if it has already been attempted, queue the escalation.
   - `UNKNOWN` → report it; do not guess.
   - A path listed under `## Ignored jobs` in `<project>/CLAUDE.md` (or under
     a listed prefix) is **not** acted on, whatever its class. Report all
     ignored rows as one collapsed line. They rejoin the policy only when the
     user asks for them by name.
4. Refresh the derived block with `espresso status write`. It rewrites only the
   marked region and refuses if anything outside it would change. Never splice
   it by hand, and never edit the rest of the file without asking.
   Remember the block covers QE job dirs only — jobs submitted from another
   directory are tracked by hand in the human sections.

Report as: what changed, what you resubmitted, what needs the user. If nothing
changed, say so in one line.
