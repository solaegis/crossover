# crossover

Bash scripts that automate CodeWeavers CrossOver bottles on macOS. Each recipe
automates what it can and documents the GUI steps for the rest. Repo conventions
for agents live in:

@AGENTS.md

## Commands

```bash
task setup         # dev deps, pre-commit hooks, bats
task check         # lint + format check + tests
task lint          # shellcheck
task format        # shfmt
task test          # bats suite
task eso           # full The Elder Scrolls Online (Steam) bottle setup
task eso:start     # Steam + ESO (-applaunch) + TTC detached
task eso:stop      # clean bottle exit (ESO + TTC + wineserver)
task eso:status    # bottle process status
task dune          # full Dune: Awakening (Steam) bottle workflow
task dune:configure # AVX env + GUI only (no BattlEye fix)
task dune:doctor   # strict health check for the Dune bottle
```

## Notes

- A recipe that cannot be automated must *say so and stop*, not half-apply and
  leave the bottle in an undefined state. The GUI steps belong in the recipe's
  own output, not only in the README.
- `.tie` / CrossTie files are a CodeWeavers-specific XML recipe format — validate
  changes against `dune:doctor`-style checks rather than assuming a schema.
- Display sleep must stay inhibited while a game is running; `~/bin/awake` and
  `~/bin/awake-off` are the existing hooks for that — reuse them, don't
  reimplement `caffeinate` handling. `eso start` turns awake on; `eso stop`/`quit` turns it off.
- Bottle operations are slow and stateful. Prefer a doctor/health-check subcommand
  over re-running a full install to test a change.
