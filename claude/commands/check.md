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
4. Refresh the derived block in `status.md` with
   `espresso status --markdown`, splicing **only** between the
   `<!-- espresso-status:begin -->` / `<!-- espresso-status:end -->` markers.
   Never touch the rest of the file.

Report as: what changed, what you resubmitted, what needs the user. If nothing
changed, say so in one line.
