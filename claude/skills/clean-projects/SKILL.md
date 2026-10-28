---
name: clean-projects
description: 'Find deletion candidates in a $WORK DFT project - tmp/scratch files, archived or backup folders, and data that has been superseded by newer correct data - and present them as a list for the user to approve. Never deletes anything until the user names which items to remove. Never proposes anything in a folder with a running or pending job, or in a folder edited in the last 30 days. Use for "/clean-projects [path]", "clean up KNbO3", "what can I delete", "free up space in the project", "remove the old PBEsol data".'
argument-hint: '[project-or-subdir, default: current project]'
---

# clean-projects

Compile a list of things that are safe to remove, show it, and delete **only what
the user picks**. Two phases, and phase 1 is read-only. Invoking this skill is a go-ahead
to *scan and propose*, never to delete.

`$WORK` = `/scratch/phys/t30411_sckagome`. Scope is the project in `$ARGUMENTS`
(default: the project containing the cwd). Never sweep other projects along.

Load the `reporting` skill for the closing table if it applies. Deleting data is
one of the decisions `$WORK/CLAUDE.md` reserves for the user, so the approval step
below is not optional.

## Hard guards — a path failing any of these is never listed

Apply to every candidate, and re-apply at delete time (state changes between the
list and the answer).

1. **Running jobs.** Get Slurm state once: `squeue -u $USER -h -o "%i %T %Z"` (the
   `%Z` is `WorkDir`), plus `espresso status <scope> --json`. A candidate is
   excluded if its own directory, **any ancestor up to the project root, or any
   descendant** is the WorkDir of a job in RUNNING, PENDING, CONFIGURING or
   COMPLETING, or is a dir `espresso status` classifies as running/queued. Ancestors
   count: a job in `doping/0.1/` protects `doping/0.1/tmp/`. If `squeue` fails,
   propose nothing and say so. Query once; do not poll or loop (see the no-Slurm-polling
   memory).
2. **Edited within the last month.** Skip the candidate if the newest mtime of
   anything inside it, or of the directory that contains it, is under 30 days ago
   (`find <cand> -type f -mtime -30 -print -quit`, and `stat -c %Y` on the parent dir,
   whose mtime moves when entries are added or removed). "Not touched in a while"
   means every file, not the directory stamp alone. A recently rewritten
   `status.md` next to the candidate does not count; a file inside the candidate's
   parent job dir does.
   **This guard is for non-tmp files only.** A job's `tmp/` (its `outdir`: `.save/`,
   `*.wfc*`, `_ph0/`, `HP/`) may be listed regardless of age when ALL of these hold:
   `espresso status` classifies the job dir as finished OK (not walltime-truncated,
   not RETRY/UNKNOWN); every result is in the output files outside `tmp/`
   (`results_*/*.pwo`, `.dyn*`, `elph_dir/`, `a2F.dos*`, `*.pdos*`, `Hubbard_parameters.dat`,
   …); and no downstream calculation needs the `.save`/`_ph0` — not a
   chained workflow (`sfw`, `nscf`/`bands`/`dos`/`projwfc` after an scf, `ph.x`/`elph`
   after an scf, `hp.x`, EPW/Wannier after an nscf, frozen-phonon step dirs, a
   convergence ladder still running) and not an `outdir` another input points at.
   Check downstream inputs' `outdir`/`prefix` before listing; an `elph` `tmp/` is only
   tmp once its `_ph0/*.phsave` is no longer read by post-processing (`g_vertex_from_phsave`
   in the notebooks).
3. **Nothing is proposed from the ignore/known lists.** Do not list anything under
   `## Ignored jobs` in `<project>/CLAUDE.md`, or PREPARED job dirs, or the items
   under `## Known inconsistencies` (status.md backups, `pseudo_old/`, the shadowing
   `pseudo/` copy, the hand-rolled elph dirs) — those wait for a request naming
   them. Mention them in one line as "known, not proposed" so the user can name them.
4. **Never the only copy of a result.** Nothing that is the sole record of a
   finished result, input (`SYSTEM.INFO`, `master.sh`, `*.in`, `*.pw*`), CIF,
   pseudopotential, `status.md`, notebook, or figure is proposed as *tmp*.

## Phase 1 — find candidates (read-only)

Large trees on scratch make `du`/`find` slow. Run the sweep in a subagent
(Explore, "medium") or in the background and keep only the findings here. Do not
delete during the sweep.

### Category A — tmp and scratch

- `tmp/`, `*.tmp`, `outdir` wavefunction leftovers (`*.wfc*`, `wfc*.dat`), `*.save/`
  directories of finished jobs whose result is already in the `.pwo`, core dumps,
  `slurm-*.out` of jobs `espresso status` reports DONE with their `.pwo` intact.
- Only where `espresso status` classifies the owning job dir as finished
  (DONE, not walltime-truncated: `JOB DONE.` alone is not proof) or dead. If the dir is
  unclassified or UNKNOWN, do not propose. A `.save` that a downstream calculation
  reads (`nscf`, `bands`, `ph.x`, `elph`, `projwfc`, `hp.x`, `sfw`, EPW, frozen-phonon
  steps) is **not** tmp; check the downstream inputs' `outdir`/`prefix` before listing.
  The 30-day guard does not apply to `tmp/` of a finished-OK job (guard 2's clause).

### Category B — archived and backup folders

- `paw-pbesol-runs/`, `*backup*`, `*.bak*`, `old*/`, `*-old/`, `archive*/`, or
  a `*_backup` results dir.
- Stale by guard 2, and not referenced by anything live: `grep -r` the project's
  `status.md`, `README.md`, notebooks, `master.sh` and inputs for the path. A live
  reference (e.g. `doping-old/` carrying the elph work) means **do not list**, or list
  under "referenced, your call" with the referrer named.

### Category C — superseded data

Data whose replacement exists and is correct. The test is evidence of a replacement,
not just age:

- Old-functional runs (PBEsol, under `paw-pbesol-runs/` or otherwise) whose **PBE
  counterpart** at the equivalent path is finished and valid. Read the functional from
  the `.pwo` (`Exchange-correlation=`) or the pseudopotentials — never from `EXCHANGE`
  in `SYSTEM.INFO` (see the project CLAUDE.md, "the trap"). Give the counterpart's path
  in the list.
- A PBEsol run with **no** PBE counterpart is the only data for that geometry: do not
  list it, and say so. Reviving it is a functional decision, not this skill's.
- Runs on an unrelaxed or since-replaced geometry, where `espresso check compare`
  shows the current tree is built on a newer relaxed structure and the new run exists.
- Earlier attempts that were re-run in place with corrected inputs (superseded
  `.pwo` copies, `.pwo.1`, `*-prev`), when the newer output is finished.

Do not treat "similar name" as replaced. Every Category C row must name what
replaced it and why the replacement is valid.

## Present the list

One table, grouped by category, biggest first, then a total. Columns:
`#`, path (relative to project), size (`du -sh`), newest mtime, why it is safe
(the evidence: replacement path, `espresso status` class, grep result), and the guard
results (no running job / >30 d).

Then, separately:

- **Excluded and why**, collapsed by reason with counts (running job in tree, edited
  <30 d, referenced, sole copy, on the known/ignored lists). Name the biggest few so the
  user sees what was deliberately kept.
- **Referenced, your call** — anything old but linked from live work.

Stop there. Ask which numbers to remove.

## Phase 2 — delete what the user picked

Only after the user names items (numbers or paths):

1. Re-run guards 1 and 2 on exactly those items. Drop and report any that no longer pass.
2. Delete by explicit path. **No globs, no `rm -rf` on a variable that could be empty,
   no `find -delete` sweeps.** Echo each path and size just before removing it.
   Symlinks: remove the link, never follow it.
3. Report what was removed, the space freed, and what was dropped at re-check.
4. Removal changes the notebook's story, so propose a short `status.md` note as a diff
   for approval (what was deleted, why, date). Do not edit `status.md` prose
   unprompted, and do not touch the `espresso-status` block by hand. If a deleted
   dir had a ledger entry, say so; do not edit `.espresso-status.json`.

Anything the user did not pick stays untouched and is not re-proposed within the same
session unless asked.
