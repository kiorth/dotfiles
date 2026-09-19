---
name: reporting
description: How to report DFT/QE work back to this user - the table shapes for job-status deltas, post-generation summaries, failure diagnoses and pre-submit blocks. Load before writing the closing summary of any espresso/QE task - /check, /resubmit-failed, /converge, generating inputs, diagnosing a failed .pwo, or submitting - and whenever a reply would otherwise be several paragraphs about several job directories.
---

# Reporting back

The user reads the report, not the transcript. **Default to a table: one row per
job directory, with a brief note on what was done to it.** Prose only for what a
table cannot carry.

## Rules that hold everywhere

- **Lead with the table.** No preamble, no restating the request, no narrating
  which commands you ran.
- **One row per job directory**, keyed by path relative to the project. The path
  is the join key the user thinks in — never re-key a table by jobid.
- **Only the delta**, or only what was asked for. A 200-row project with three
  changes produces a three-row table.
- **If nothing changed, say so in one line** and stop. Do not table an empty set.
- **An empty action cell is `—`.** Do not omit the row; "seen, nothing needed" is
  a result.
- Process narration — which file you edited, where the backup went — belongs in
  the ledger `note`, not the report. Physics numbers stay in the report.
- Never pad with what a command already prints. Link the path; they can `cat` it.

## Job status — `/check`, `/resubmit-failed`

| dir | status | action |
|---|---|---|
| `0.2/bands-160` | RUNNING 1/2 → **OK 2/2** | — |
| `0.2/bands-6-Pm` | FAILED `qe_max_cpu_time` | resubmitted **20321451**, `--max-time` 1.5× |
| `0.2/bands-99-P4mm` | FAILED `qe_max_cpu_time` | resubmitted **20321452**, `--max-time` 1.5× |

Then, and only if non-empty, in this order:

1. **Needs you** — HUMAN escalations and UNKNOWNs, one line each. Say
   "nothing needs you" explicitly when there is nothing; its absence is
   ambiguous.
2. **Worth knowing** — at most two lines, and only for a number that changes a
   decision. "NSCF reached 611/689 kpts, so it needs ~21 h" earns a line because
   it is why the bump is sufficient. "I edited master.sh rather than
   regenerating" does not.

Drop a row out of the table once it is OK and stays OK — the next check reports
the tree that moved, not the tree.

## Post-generation — after `espresso input …`

| file | purpose |
|---|---|
| `results_scf/KNbO3.scf.pwi` | SCF input |
| `master.sh` | driver, steps SCF → NSCF-unfold |

Then non-defaults as `key: default → used`, "none" if there are none; the
one-line structure-check verdict; and the exact `sbatch` line, not run.

## Failure diagnosis

The **actual error text first, verbatim, fenced** — never paraphrased, never
summarised into a cell. Then one table:

| dir | signature | cause | fix |
|---|---|---|---|

Both halves are required. The text is what the user recognises; the row is what
is actionable.

## Pre-submit

The `#SBATCH` block as a literal excerpt with changed lines marked
`(was …)`, then the exact `sbatch` line. Not a table — the block is the artefact
they are checking, and reformatting it hides what changed.

## status.md

The prose sections are the durable record and the reason the next session does
not re-learn what this one did. The user does not read them; write them anyway,
for you.

**Never machine-generate that prose, and never edit it without showing the diff
first.** When a session produces a finding worth keeping, close the report with
one line offering to draft the entry. Do not write the diff unprompted, and do
not offer twice for the same finding.

Refresh the derived block with `espresso status write`. It is not part of the
report — do not paste it back.
