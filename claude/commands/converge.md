---
description: Run the cutoff/k-point convergence ladder for a system
---

Run the convergence ladder for `$ARGUMENTS` using the existing CLI — do not
hand-roll the directory structure.

1. Confirm the structure first. If a relaxed structure exists
   (`SYSTEM.RELAXED.INFO`, `*-relaxed.cif`, `*vc-relax.pwo`), verify the inputs
   are built on it with `espresso check compare`, and stop if they are not.
2. Generate: `espresso convergence cutoff` and `espresso convergence kgrid`
   with the parameters the user asked for. Show the resource block and the
   exact `sbatch` lines, and get a go-ahead before submitting.
3. Track with `espresso status` while they run.
4. Analyse with `espresso post convergence` once complete, and report the
   converged values with the tolerance used — not just the ladder.

Convergence targets are a physics decision. Ask which quantity and tolerance
matter if the user has not said.
