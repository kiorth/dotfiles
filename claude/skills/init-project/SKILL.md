---
name: init-project
description: 'Bring a $WORK project folder under the semi-automatic DFT workflow (derived espresso-status block in status.md, .espresso-status.json retry ledger, physics-only per-project CLAUDE.md). Two modes. An existing project: baseline it as it stands, record its inconsistencies without fixing them, and hold every new calculation to the workflow. An empty or missing folder: set up a new material from the user''s prompt. Use for "/init-project <path> [description]", "set up the workflow for Nb", "start a new project for MgB2".'
argument-hint: <project-dir> [what the project is for]
---

# init-project

Bring one project folder under the workflow described in `$WORK/CLAUDE.md`.
`$WORK` = `/scratch/phys/t30411_sckagome`. **A project is an immediate child of
`$WORK`.** Invoking this skill on a project is the user's go-ahead for **that project
only**. Never sweep other folders along with it.

Load the `dft` skill too. Its rules on `SYSTEM.INFO`, the relaxed-structure check and
`status.md` all apply here, and this skill does not repeat them.

## 0. Decide the mode

Resolve `$ARGUMENTS` to a path. A bare name means `$WORK/<name>`.

- The path is not an immediate child of `$WORK` → stop and say so.
- `theo-failure-tests` → it is dormant and out of scope permanently. Stop, unless the
  user named it explicitly in this message.
- The folder is missing, or empty apart from dotfiles → **§2 New project**.
- Otherwise → **§1 Existing project**.

Report which mode you picked, and why, in one line before doing anything else.

## 1. Existing project

The folder predates the workflow, so it will contain inconsistencies: hand-written
inputs, stray `status.md` files, `SYSTEM.INFO` values that disagree with the
pseudopotentials, runs built on an unrelaxed cell, old jobs that never finished.

**Record them. Do not fix them.** Do not move, rename, delete, regenerate or resubmit
anything that already exists. Each one gets fixed later, when the user asks for that
specific fix. The same applies to adjacent checks: this skill *observes* the old tree.

**Every new calculation follows the workflow in full**, however the old ones were made:
generated with `espresso input`, built on the relaxed structure (`espresso check
compare`), functional confirmed from the pseudopotentials or the `.pwo`, pre-submit block
shown. "The old runs in this folder did it differently" is never a reason to deviate.

### 1a. Survey (read-only)

1. Check what is already in place: markers in `status.md`, `CLAUDE.md`,
   `.espresso-status.json`, and within `CLAUDE.md` the `## Known inconsistencies` and
   `## Ignored jobs` sections. **Fill whichever are missing and leave the rest alone**,
   section by section — a project converted before this skill existed will have the
   files but not the sections. Say up front which parts are already there. Stop only
   when every part exists; then report that and do nothing.
2. `espresso status <project> --no-slurm`, then without `--no-slurm`. The first run
   shows what the files say; the second adds Slurm.
3. Find the physics facts, read from what actually ran:
   - the functional: `Exchange-correlation=` in the reference `.pwo` files, and the UPF
     headers in every `pseudo*/` directory. `EXCHANGE` in `SYSTEM.INFO` is intent, not
     evidence;
   - the pseudopotentials: type, valence, and which directory is live;
   - the relaxed reference structure (`vc-relax`/`relax` `.pwo`, `*-relaxed.cif`,
     `SYSTEM.RELAXED.INFO`) and its cell;
   - the settled parameters: `CUTOFF`, `ECUTRHO`, `SMEAR`, `KGRID`, and where they were
     converged.
4. Collect the inconsistencies. Look at least for:
   - more than one `status.md`, or `status.md.bak*` files;
   - a `SYSTEM.INFO` whose `EXCHANGE` disagrees with its pseudopotentials;
   - more than one `pseudo*/` directory, or a subtree with its own local `pseudo/`;
   - job dirs without a `master.sh`, i.e. hand-rolled runs that `espresso status`
     cannot see;
   - jobs submitted from somewhere else (python drivers, `../<other project>`), which
     Slurm attributes to a different `WorkDir`;
5. Collect **every job that has not completed**: each row that is not `OK`. That means
   `RETRY`, `HUMAN`, `UNKNOWN` and `PREPARED` (generated, never submitted). List
   `RUNNING` rows too, as in progress, but do not ask about them.

### 1b. Unfinished jobs: ask, never resubmit

**Resubmit nothing during init, even a `RETRY` row that the policy would normally
resubmit without asking.** The user may have left a job unfinished on purpose, for a
reason the classifier cannot see.

List the unfinished jobs in one table: path, class, and the reason `espresso status`
gives. Then ask which of them should be completed. Group by subtree where that keeps
the question short (e.g. "everything under `spg_160_R3m/doping-old/`: 12 rows").
For each answer:

- **Complete it:** the job joins the retry policy like any new job. Handle it as the
  `dft` skill and `/check` would, starting from its current class.
- **No, or no answer yet:** the job is **ignored**. `/check` and `/resubmit-failed`
  leave it alone whatever its class, and report all ignored jobs as one collapsed
  line. It stays ignored until the user asks for it by name.

Ignored jobs are listed in the project's `CLAUDE.md` under `## Ignored jobs`, one path
per line with its class and the date. Where a whole subtree is ignored, list its prefix
instead of every row. When the user later asks for an ignored job, remove its line as
part of that change and show the diff.

### 1c. Write, each with approval

Show each file in full, or as a diff for an existing file, and ask before writing it.
Batch the approvals into one question where possible.

1. **`<project>/CLAUDE.md`, physics only.** Use `$WORK/KNbO3/CLAUDE.md` as the model:
   - what the project is for;
   - the functional and pseudopotentials, *with how each was confirmed*;
   - the settled parameters and where they were converged;
   - the relaxed reference structure;
   - any trap the survey found;
   - `## Known inconsistencies — not to be fixed until asked`: each finding from 1a.4,
     one line apiece, with its path;
   - `## Ignored jobs`, from the answers in 1b.

   Leave out anything you could not confirm, and say so, rather than writing a guess.
   Cluster and retry rules belong in `$WORK/CLAUDE.md`, not here.
2. **`status.md`.**
   - If it exists: run `espresso status write <project>`. With no markers present it
     *appends* the block, a pure addition, which is exempt from approval. Do not
     reorganise the existing notes to fit the new layout; that would be fixing an
     inconsistency.
   - If it is missing: propose the skeleton in §3, then run `espresso status write`.
3. **The ledger.** Run `espresso status <project> --record` once, so the job ids Slurm
   still remembers are persisted before `sacct` ages them out.

## 2. New project

Starting a new material is the gate in `$WORK/CLAUDE.md` that always needs a decision.
The user's prompt is that decision for **whatever it states explicitly**. Ask, in a
single `AskUserQuestion`, only for what it leaves open:

- **the structure source**: a CIF/POSCAR path or a QE file. Never download a structure
  or invent one;
- **the functional**;
- **the pseudopotential source**: a directory to copy from. Never download.
  If an existing project already has a suitable set, offer it, and say which project;
- **what the project is for**, if it is not already obvious. It goes in `CLAUDE.md`.

Then:

1. `mkdir` the folder and `pseudo/`, and copy the pseudopotentials into `pseudo/`.
2. `espresso system-info <structure file> --pseudo-dir <project>/pseudo`. Discover the
   remaining flags with `--help`.
3. Confirm that the pseudopotentials agree on one functional, and that it is the one
   asked for. A mismatch stops here: report it, and do not choose for the user.
4. `espresso check spg <structure>`, and report the space group.
5. Write `CLAUDE.md` (physics only, as in 1c.1, with no ignored-jobs or
   inconsistency sections) and the `status.md` skeleton (§3). Show both and ask. Then run
   `espresso status write`.
6. **Propose** the first calculations: the convergence ladder (`/converge`), then
   `vc-relax`, then whatever the prompt asked for. Generate nothing and submit nothing
   until the user agrees, because each costs allocation. Once they agree, follow the
   `dft` skill as usual.

A new project has no ignored jobs, so everything in it is under the retry policy from
the first job.

## 3. The status.md skeleton

Headings only, plus the marker pair. The prose is the user's.

```markdown
# Status — <NAME>

_Last updated: <date>_

<one line: what this project is for>

## Parameters

## Jobs

### DFT — derived, do not hand-edit

Regenerate with `espresso status write`. Facts only; the reasoning lives below.

<!-- espresso-status:begin -->
<!-- espresso-status:end -->

### Property / driver jobs — not covered by the block

## Results

## Findings that cost time — do not repeat

## Open items

## Notes
```

## 4. Report

Load the `reporting` skill. Then send one table covering what was created, what was
already there, the job-dir counts by class, and the inconsistencies found. Close with the
next step you propose.
