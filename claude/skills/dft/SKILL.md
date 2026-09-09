---
name: dft
description: 'Quantum ESPRESSO workflow agent for this cluster - edit/generate QE inputs and Slurm scripts via the `espresso` CLI, verify the relaxed structure is the one being used, diagnose failed runs via the mechanical RETRY/HUMAN classifier, submit jobs, and keep the one-per-project status.md notebook. Use for any QE/pw.x/ph.x task: creating scf/relax/vc-relax/bands/dos/phonon/elph/sfw/doping inputs, checking .pwo outputs, writing or submitting master.sh, "why did this job fail", "check on my jobs", or updating status.md. Job state comes from `espresso status`, not from reading status.md.'
---

# DFT agent (Quantum ESPRESSO)

Drive the user's own `espresso` CLI. Never hand-write a `.pwi` or a Slurm script when a
CLI subcommand can generate it, and never write ad hoc analysis scripts or plots unless
explicitly asked.

## 0. Orientation (do this first, every time)

- `$WORK` = `/scratch/phys/t30411_sckagome`.
- **A project is an immediate child directory of `$WORK`** (e.g. `$WORK/KNbO3`,
  `$WORK/theo-failure-tests`, `$WORK/Nb`). Everything below it — space groups,
  `doping/`, `ce/`, individual configs — belongs to that one project.
- **`<project>/status.md` is the project notebook. Exactly one per project.**
  It holds parameters, results, interpretation and the findings that cost time to
  learn. It is *not* the source of truth for job state.
- **Job state comes from `espresso status`**, which derives it from the filesystem
  and Slurm. Run it before doing anything else; read `status.md` for the physics
  context and for what has already been tried and why.
- `$WORK/CLAUDE.md` carries the retry policy. Follow it: act on `RETRY`, escalate
  `HUMAN`, and do not ask permission for bookkeeping.

Discover the toolset with `espresso <cmd> --help` rather than guessing flags; the CLI
changes. Top-level commands: `check`, `clean`, `cluster`, `compute`, `convergence`,
`input`, `para`, `post`, `status`, `structure`, `system-info`.

## 1. Generating / editing inputs

`SYSTEM.INFO` is the central config (NAME, CUTOFF, ECUTRHO, SMEAR, KGRID, EXCHANGE,
NBANDS, PSEUDO_DIR, ATOMIC_SPECIES, ATOMIC_CRYST_POSITIONS, LATTICE, QE_CRYST_PATH).
Workflows read it from the cwd unless `--system-info` is given.

- Create/refresh it from a structure or a QE file: `espresso system-info <file>`;
  update in place with `espresso system-info update`.
- Generate a workflow: `espresso input {scf|relax|vc-relax|bands|dos|phonon|elph|fermi|sfw|doping} [opts]`.
  This writes `results_<workflow>/` plus `master.sh`. **It never runs anything.**
- Override a SYSTEM.INFO value for one run with `--set KEY=VALUE` (repeatable) instead
  of editing SYSTEM.INFO, unless the change is meant to be permanent.
- To derive a new calculation from an existing input (preserving DFT+U, Hubbard, custom
  settings): `--from-input <path.pwi>`.
- `--max-time` sets QE's `max_seconds`; Slurm time is automatically `max-time + 1h`
  unless `--slurm-time` is also given. Prefer setting `--max-time` so QE stops cleanly
  and can restart, rather than being killed by Slurm.

### Resource defaults

Resolution order, lowest to highest priority:
1. Built-in `generic` profile (`espresso/slurm/profiles.py`) — per workflow nodes/ntasks/mem/time.
2. `~/.config/espresso/espresso-cluster.json` — cluster prelude (module purge; triton/2024.1-gcc;
   python/3.11.6; gcc/12.3.0 openmpi/4.1.6; activate `$PYTHON_ENVS/espresso`) and per-workflow
   overrides (currently `vc-relax` and `phonon`: 2 nodes / 80 tasks / 108:00:00; `sfw-*`: 2 nodes).
3. Explicit `--slurm-*` / `--max-time` / `--kppra` / `--nbnds` flags.

Read both sources before reporting what was changed — do not assume the built-in profile
is what applied.

### Cluster hardware and partition caps (Triton)

| partition | nodes | cores/node | mem/node | MaxNodes |
|---|---|---|---|---|
| `batch-milan` | 32 | 128 | 510000 M | **2** |
| `batch-skl` | 46 | 40 | 191000 M | 16 |
| `batch-csl` | 48 | 40 | 191000 M | 16 |
| `batch-hsw` | 16 / 54 | 24 | 257660 M / 128640 M | 16 |
| `batch-bdw` | 8 | 28 | 128650 M | 16 |

Every batch partition is `TIMELIMIT 5-00:00:00`; `hugemem` is 1 node / 80 cores / 2048000 M / 3 d.

- **`batch-milan` caps at 2 nodes.** Any job needing >191000 M per node can *only* land on milan,
  so it is simultaneously memory-bound to milan and capped at 2 nodes there. For such a job
  "add more nodes" is not a lever — check `scontrol show partition <p> | grep MaxNodes` before
  proposing one. Symptom of exceeding it: `sbatch: Requested node configuration is not available`.
- Scale inside the cap with **tasks per node** instead. Big-memory QE jobs routinely sit at 20 of
  milan's 128 cores because `--mem-per-cpu` is the binding constraint, leaving 84% of the node
  idle. Raising `--ntasks-per-node` while lowering `--mem-per-cpu` by the same factor holds
  memory/node constant and multiplies the ranks.
- The submit filter rewrites `Partition=` to all five batch partitions no matter what you asked
  for. A memory request only milan can satisfy therefore parks on `Reason=BadConstraints` until
  milan frees. That is normal, not terminal — confirm with
  `sbatch --test-only <same flags> --partition=batch-milan --wrap="true"`, which names the nodes
  and an estimated start if the shape is satisfiable at all.

### Parallelising ph.x — use k-point pools

`srun ph.x` with no `-nk` runs `npool=1`: pure plane-wave parallelism, walking every k-point
serially. Check any `.pwo` for the line `R & G space division: proc/nbgrp/npool/nimage`. For DFPT
the linear solve is ~95% of the wall time (`ch_psi` in the final timing block) and parallelises
over k almost perfectly, so pools are the highest-value flag available.

- Choose pools so that **procs-per-pool stays equal to a shape already proven to run**. Per-rank
  G-space memory is set by procs-per-pool, not by total ranks; holding it fixed and adding pools
  buys near-linear speedup while *lowering* per-rank memory, since each pool stores fewer k-points.
  A run proven at 40 procs / 189 k-points becomes 80 ranks `-nk 2` = 2 pools × 40 procs / 95 k each.
- Pools are legal for `electron_phonon='interpolated'`. The `npool.ne.1` guard at
  `PHonon/PH/phq_readin.f90:828` fires only for `elph_mat` (Wannier/EPW).
- **`-nimage` is barred outright for el-ph** (`phq_readin.f90:839`). Do not reach for it.
- Changing `-nk` between runs is safe: ph.x reads the *collected* `.save` and redistributes
  ("Reading collected, re-writing distributed wavefunctions").

When an irrep times out at `max_seconds`, the levers are, in order: pools (`-nk`), more
tasks/node, then looser `tr2_ph`. Never more walltime — 5 d is the cluster maximum.

## 2. Mandatory relaxed-structure check

If the tree contains a relaxed structure, **confirm before submitting** that the new
calculation is built on it, not on the raw CIF or a stale cell. This has silently gone
wrong repeatedly in this project.

Look for: `SYSTEM.RELAXED.INFO`, `*-relaxed.cif`, `vc-relax/results_vc_relax/*.vc-relax.pwo`,
`*/results_relax/*.relax.pwo`. Then run:

```
espresso check compare <relaxed.pwo> <new_input.pwi> [<raw.cif>]
```

Report the aligned table and state explicitly whether the cell parameters and space group
of the new input match the relaxed structure. If they do not match, **stop and say so**
before submitting.

Also verify the functional actually used, not the one claimed: `SYSTEM.INFO` may say
`EXCHANGE='pbe'` while the pseudopotentials in `PSEUDO_DIR` are PBEsol. Grep the reference
`.pwo` for `Exchange-correlation=` and compare. Pseudos in
`$WORK/KNbO3/pseudo/` were switched from PAW-PBEsol to PBE on **2026-06-23** — any run
older than that is PBEsol regardless of what SYSTEM.INFO says.

## 3. Post-generation summary

After generating files, always print a short summary — no more than this:

1. **Files written** — path and one-line purpose each (`results_scf/X.scf.pwi`, `master.sh`, …).
2. **Non-default parameters** — a compact list of every value that differs from the
   defaults resolved in §1, in `key: default → used` form. Say "none" if nothing differs.
3. **Structure check** — the one-line verdict from §2.
4. **Submit command** — the exact `sbatch` line, not run.

## 4. Checking outputs and diagnosing failures

`espresso check <file>` handles `SYSTEM.INFO`, `.pwi`, `.pwo`, and `para_phonons`/`para_elph`
trees; for a `.pwo` it prints status, energetics, pressure, max force, lattice and position
changes, and initial/final space group. Use it before reading raw output.

**A run is only complete if `JOB DONE.` is present AND `Maximum CPU time exceeded` is
absent.** Slurm reporting `COMPLETED` is not sufficient — QE prints `JOB DONE.` even when
it stopped itself at `max_seconds`. This exact false positive has bitten this project
several times. Check both:

```
grep -c "JOB DONE\." out.pwo; grep -c "Maximum CPU time exceeded" out.pwo
```

When a calculation failed, report **the actual error text**, then the cause, then a
concrete fix.

The signature → cause → fix table now lives in
`espresso/defaults/failure_signatures.toml`, as data. `espresso status` reads it to
classify each failure as **RETRY** (walltime, node failure, preemption, stale
scratch, launch fault — resubmitting with the named knob is correct) or **HUMAN**
(SCF non-convergence, OOM, `cdiaghg`, missing pseudopotential, malformed input,
unconverged bands, `ECUTRHO` too low, symmetry mismatch — resubmitting unchanged is
pointless).

To see the current table:

```
espresso status --json    # each row carries signature, cause, fix and remedy
sed -n '1,40p' "$(python -c 'from espresso.defaults.config import get_signatures_path as g; print(g())')"
```

**Add a new failure mode by editing that TOML, not by editing this file or writing
new conditionals.** A row needs `id`, `match`/`regex`, `where`, `verdict`, `cause`,
`fix`, `priority`, and a `remedy` if it is RETRY. Priority decides which signature
wins when several match, which is what keeps `Maximum CPU time exceeded` ahead of a
bare `JOB DONE.`.

For `ph.x`, the classifier in `espresso/post/grep.py:ph_job_status` returns
`done` / `failed (no convergence)` / `failed (bad termination)` / `failed (early stop)` /
`timed out` / `incomplete`.

Never resubmit an unchanged job that has already failed twice for the same reason without
saying so and proposing an actual change.

## 5. Submitting

**A new calculation needs a go-ahead. A resubmission of a RETRY-classified failure
does not** — see the retry policy in `$WORK/CLAUDE.md`.

For a new calculation:

1. Show the resource block and the submit command; get the user's go-ahead.
2. `sbatch master.sh` (or `array_submit.sh` for array studies) from the job directory.
3. Capture the returned job id.
4. Record it: `espresso status record <job-dir> --jobid <id>`.

For a resubmission of a `RETRY` classification: apply the remedy the classifier
names, submit, and record it with `--outcome RETRY` so the budget is spent:

```
espresso status record <job-dir> --jobid <id> --outcome RETRY
```

Then report it at the next `/check` rather than interrupting. The budget is **5 per
job directory**; past that, escalate regardless of class. Never resubmit an unchanged
input that has already failed twice for the same reason.

## 6. status.md — the project notebook

**One per project, at `<project>/status.md`.** It is a lab notebook: parameters,
results, interpretation, and the findings that cost time to learn. That content is
written by hand. **Always show the proposed edit as a diff and ask permission before
writing any of it**, including appending a single line.

The job list is no longer hand-maintained. It lives in a derived block that
`espresso status --markdown` owns:

```markdown
<!-- espresso-status:begin -->
| path | jobid | slurm | steps | class | retries |
|---|---|---|---|---|---|
| `spg_160_R3m/bands` | 19779812 | TIMEOUT | 2/3 | RETRY | 1/5 |
<!-- espresso-status:end -->
```

Regenerate it with `espresso status write` (add `--dry-run` to preview). That
command rewrites only the marked region and **refuses to write at all** if any
line outside it would change, so it is safe to run unattended. Do not splice the
block by hand. **Never edit anything outside the markers without asking.** Facts go in the block; reasoning goes in the human sections, keyed by the
same job-dir path:

```markdown
## Notes
- `q1/irr_55_55` — 19981733 timed out at iter 26, |ddv_scf|^2=1.544E-20 vs
  tr2_ph=1e-20, ~2 iterations short.
```

### Consolidating stray status.md files

If a `status.md` exists anywhere below the project root: read it, merge the
still-relevant content into `<project>/status.md`, show the merge as a diff and ask
permission to write, **then ask separately** for permission to delete the stray.
Never delete before the merge is written.

## 7. Checking on jobs

Run `espresso status` — do not reconstruct job state by hand from `sacct` and
`status.md`.

```
espresso status                     # the project containing the cwd
espresso status $WORK/KNbO3         # a named project
espresso status --needs-action      # only RETRY / HUMAN / UNKNOWN
espresso status --json              # machine-readable
```

It walks the project, joins `squeue`/`sacct` by `WorkDir` (two subprocess calls for
the whole scan), applies the §4 completion rule per step, and classifies each job
directory as `OK` / `RUNNING` / `PREPARED` / `RETRY` / `HUMAN` / `UNKNOWN` with a
reason and a suggested remedy. It is read-only: it never submits, and the only file
it writes is the retry ledger, under `--record`.

Then apply the retry policy in `$WORK/CLAUDE.md`: act on `RETRY`, escalate `HUMAN`,
never treat `UNKNOWN` as success. Report a short table of what changed, and refresh
the derived block with `espresso status write`.

**The block covers QE job directories only.** Anything submitted from another
directory — python drivers, post-processing, cross-project scripts — is attributed
to wherever its Slurm `WorkDir` points, and will not appear. Track those by hand in
the human sections, and say so there, or a future reader will read the block as
complete coverage when it is not.
