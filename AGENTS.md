## Learned User Preferences

- Prefer root-level Taskfile entry points (e.g. `task eso`, `task dune`) over double-namespaced included tasks; delegate to internal included tasks for implementation.
- CLI/log color on by default; disable with `--no-color` or `CROSSOVER_NO_COLOR=1` (project-specific, not global `NO_COLOR`).
- Prefer notes + Mac-env Crosstie recipes (`eso_steam` / `dune_steam` pattern) over encoding Steam MSI or installer globs; Steam install stays CrossOver’s built-in Steam crosstie.
- Keep Taskfile/`CROSSOVER_BOTTLE` defaults identical to Crosstie `<name>` / CrossOver on-disk bottle folders (CrossOver strips `:`); never set file-level `CROSSOVER_BOTTLE` on included eso/dune Taskfiles (values leak across recipes).

## Learned Workspace Facts

- Bash project for CodeWeavers CrossOver bottles on macOS; recipes: `eso` (`The Elder Scrolls Online (Steam)`) and `dune` (`Dune Awakening (Steam)`).
- `bin/crossover` is a recipe-based CLI dispatcher; helpers live in `lib/crossover.sh`, `lib/eso_*.sh`, and `lib/dune_*.sh`; orchestration via `scripts/eso/bottle.sh` and `scripts/dune/bottle.sh`.
- Default bottles match Crosstie `<name>`: `The Elder Scrolls Online (Steam)` (ESO Steam AppID `306130`) and `Dune Awakening (Steam)` via `CROSSOVER_BOTTLE` (CrossOver strips `:` from bottle names).
- ESO clean exit: `crossover eso quit` / `eso stop` (taskkill Steam/ESO/TTC → wineboot end-session → wineserver -k → host SIGTERM/SIGKILL fallback → clear TTC_Lock → awake off); play session: `eso start` (Steam `-applaunch 306130` + TTC detached); `eso launch game` for applaunch alone; `eso status` counts bottle-scoped processes via argv bottle path, bottle-root `lsof`, or timed per-PID `lsof` for PE candidates (eso64/Client/steam — PE has no `WINEPREFIX` in `ps eww`); `eso launch ttc`. Never `wineserver -k0` (signal 0 is a no-op on CrossOver).
- Primary entry points: `task eso`, `task eso:start`, `task eso:stop`, `task dune`; Dune BattlEye repair: `task dune:fix-battleye` (`--full-reset` deletes game BattlEye dir → Steam verify).
- Dune on Apple Silicon needs `ROSETTA_ADVERTISE_AVX=1` in bottle `cxbottle.conf` (CrossOver GUI: Advertise AVX capabilities); `task dune:configure` writes it. Bottle tuning: Graphics=D3DMetal, Sync=MSync; launch via `task dune:launch:game` (DuneSandbox_BE.exe).
- ESO Steam bottle: GUI Graphics=DXMT, Sync=MSync; Mac env `WINEMSYNC=1`, `D3DM_ENABLE_METALFX=0`, `DXMT_ENABLE_NVEXT=0`; never set `CX_GRAPHICS_BACKEND` in `cxbottle.conf`; keep High Resolution Mode (HiDPI) off so `FullscreenWidth`/`Height` are not doubled; first Steam Play runs the ZeniMax Online installer (two-stage after Steam download — click INSTALL).
- BattlEye **Driver Load Error (1053)** on CrossOver is the kernel driver (`BEDaisy`) failing — expected hard stop; VPN/`fix-battleye` do not fix it. Proton BattlEye Runtime (Steam 1161040) is Linux-only.
- `task timemachine` excludes all CrossOver bottles from Time Machine.
- Crossties in `ties/`: `eso_steam.tie` / `dune_steam.tie` (greenfield notes + Mac env; bottle name = recipe `<name>`), `eso_standalone.tie`, `ttc_client.tie` (TTC notes + .NET 4.8 into the ESO Steam bottle; no Client.exe installer — Minion supplies Client; if CrossOver asks for an installer, Cancel and install **Microsoft .NET Framework 4.8** from the catalog into that bottle).
- TTC network: intermittent Wine/Mono `NameResolutionFailure`/timeouts in Client/ErrorLog — `crossover eso fix-ttc-net` / `task eso:fix-ttc-net` pins bottle hosts and probes host vs Wine DNS.
- CI: use system `shellcheck` (not Docker `shellcheck-precommit`); `eso start` bats asserts `-applaunch` + Darwin `open` vs Linux detached wine.
