# crossover

Bash scripts for **CodeWeavers CrossOver** bottles on macOS. Each **recipe** (subcommand) automates what it can and documents the GUI steps for the rest.

## Recipes

| Recipe | Bottle | Description |
|--------|--------|-------------|
| `eso` | `The Elder Scrolls Online (Steam)` | Steam + Elder Scrolls Online + Minion + TTC |
| `dune` | `Dune Awakening (Steam)` | Steam + Dune: Awakening + BattlEye repair |

## Prerequisites

- [go-task](https://taskfile.dev/) (`task`)
- [uv](https://docs.astral.sh/uv/) (runs pre-commit only; no application Python)
- Optional locally (CI installs these): `shellcheck`, `shfmt`, `bats`

On macOS with Homebrew:

```bash
brew install go-task uv shellcheck shfmt bats-core
```

## Quick start

```bash
task setup
task check
```

Run the CLI:

```bash
bin/crossover help
bin/crossover eso paths
bin/crossover eso doctor
bin/crossover eso setup
bin/crossover eso launch steam
bin/crossover eso launch game
bin/crossover eso status
bin/crossover eso quit
bin/crossover eso launch ttc
bin/crossover dune paths
bin/crossover dune doctor
```

## Dune: Awakening recipe (`crossover dune`)

BattlEye-protected multiplayer survival game (Steam AppID **1172710**). CodeWeavers rates it [Installs, Will Not Run](https://www.codeweavers.com/compatibility/crossover/dune-awakening). This recipe automates user-mode BattlEye repair and bottle tuning; it **cannot** load BattlEye’s Windows kernel driver.

> **Hard stop — Driver Load Error (1053)**
> If BattlEye Launcher shows `Failed to initialize BattlEye Service: Driver Load Error (1053)`, CrossOver has hit the ceiling. That is BE’s **kernel** driver (`BEDaisy`) failing under Wine — expected on macOS.
> **Does not help:** VPN, `task dune:fix-battleye`, Proton BattlEye Runtime, graphics/sync tweaks, or launching without the BE wrapper (online still requires BE).
> **Real options:** Funcom single-player if/when it ships without BE; Windows 11 ARM (Parallels) or cloud/remote Windows for native BattlEye (Parallels may still block on DX12).

| Component | In bottle? | How |
|-----------|------------|-----|
| **Steam** | Yes | CrossOver GUI — open `ties/dune_steam.tie` (bottle **Dune Awakening (Steam)**; CrossOver strips `:`) or install “Steam” and Edit the bottle name to match |
| **Dune: Awakening** | Yes | Install via Steam; ~44 GB |
| **BattlEye** | Partial | `task dune:fix-battleye` resets cache, registers **user-mode** BEService; **kernel driver will not load** (see 1053 above) |

```bash
export CROSSOVER_BOTTLE="Dune Awakening (Steam)"   # also the default (no colon)
task dune:configure      # ROSETTA_ADVERTISE_AVX=1 on Apple Silicon
task dune:fix-battleye   # repair "Updating…" hang / (4, 40000430)
task dune:launch:game    # launch via DuneSandbox_BE.exe
task dune:doctor
```

**CrossOver GUI (manual):** bottle Settings → **Graphics: D3DMetal**, **Sync: MSync**.

**If BattlEye hangs on "Updating…"** (not 1053):

1. `task dune:fix-battleye -- --full-reset` (removes game `BattlEye/` — **pauses here on purpose**)
2. `task dune:verify-steam` (or Steam → Verify integrity manually)
3. `task dune:fix-battleye` again
4. Optional: connect a **VPN** during first BE **update**, disconnect after it passes

**`(4, 40000430)` on service install:** BattlEye's GUI installer often fails under CrossOver/Wine. Run `task dune:fix-battleye` — it registers **BEService** via `sc.exe` instead. VPN does not fix this error. This is separate from **1053**.

**Does not help on macOS:** Proton BattlEye Runtime (Steam Tools, App 1161040) — Linux/Proton only.

**Fallbacks if multiplayer still blocked (including after 1053):** Funcom's announced single-player mode (may bypass BE); Windows 11 ARM VM (Parallels) or cloud Windows for native BattlEye.

## Environment variables (Dune recipe)

| Variable | Purpose |
|----------|---------|
| `CROSSOVER_BOTTLE` | Bottle name (default: `Dune Awakening (Steam)`) |
| `DUNE_STRICT_DOCTOR` | Set to `1` to require CrossOver + bottle/BattlEye checks |
| `DUNE_SKIP_GUI_WAIT` | Set to `1` to skip interactive bottle-create prompt |

## ESO recipe (`crossover eso`)

| Component | In bottle? | How |
|-----------|------------|-----|
| **Steam** | Yes | CrossOver GUI — open `ties/eso_steam.tie` (bottle **The Elder Scrolls Online (Steam)**) or install “Steam” and Edit the bottle name to match |
| **ESO** | Yes | Install via Steam inside the bottle; run once to finish setup |
| **Minion** | No (native Mac app) | Install [Minion for Mac](https://www.mmoui.com/minion/); `launch minion` opens Minion.app — point it at Mac AddOns |
| **TTC** | Yes (AddOns Client) | Tamriel Trade Centre `Client.exe` under Mac `live/AddOns`; `launch ttc` / Mac helper app |

```bash
export CROSSOVER_BOTTLE="The Elder Scrolls Online (Steam)"   # also the default
task eso
bin/crossover eso doctor
bin/crossover eso quit                    # clean bottle exit after play
```

## Environment variables (ESO recipe)

| Variable | Purpose |
|----------|---------|
| `CROSSOVER_BOTTLE` | Bottle name (default: `The Elder Scrolls Online (Steam)`) |
| `CROSSOVER_ROOT` | CrossOver SharedSupport root (auto-detected) |
| `ESO_STRICT_DOCTOR` | Set to `1` to require CrossOver + bottle checks in `doctor` |
| `ESO_MAC_ADDONS` | Mac live AddOns directory |
| `CROSSOVER_PREFIX` | Override bottle `drive_c` prefix |
| `ESO_WIN_ADDONS` | Windows-side AddOns path inside the bottle |
| `CROSSOVER_NO_COLOR` | Set to `1` to disable ANSI colors (same as `--no-color`) |
| `CROSSOVER_TIME_MACHINE_PERSISTENT` | Set to `1` to also run `tmutil addexclusion -p` (requires `sudo`) |

Typical CrossOver layout:

```text
~/Library/Application Support/CrossOver/Bottles/<BOTTLE>/drive_c/
  users/crossover/Documents/Elder Scrolls Online/live/AddOns/
```

JSON paths:

```bash
bin/crossover eso paths --json
```

## Crossties

Custom CrossOver `.tie` recipes live under [`ties/`](ties/). Install via CrossOver → **Install a Windows Application** (or `open ties/eso_standalone.tie` on macOS).

| Tie | Bottle | Notes |
|-----|--------|-------|
| `eso_steam.tie` | `The Elder Scrolls Online (Steam)` | Notes + Mac env; bottle name = Crosstie `<name>` (matches `task eso`) |
| `eso_standalone.tie` | `The Elder Scrolls Online (Standalone)` | Bethesda.net launcher (non-Steam); shares Mac `live/` AddOns with a Steam bottle |
| `dune_steam.tie` | `Dune Awakening (Steam)` | Install notes for Steam + BattlEye tuning (bottle name = Crosstie `<name>`; CrossOver strips `:`) |
| `ttc_client.tie` | `The Elder Scrolls Online (Steam)` (existing) | Notes + .NET 4.8 only (not an installer for Client.exe) |

The `task eso` default bottle is `The Elder Scrolls Online (Steam)` (open `ties/eso_steam.tie` for greenfield).
The `task dune` default bottle is `Dune Awakening (Steam)` (open `ties/dune_steam.tie` for greenfield; CrossOver strips `:` from bottle names).

## Layout

```text
bin/crossover           Main CLI (recipe dispatcher)
lib/
  crossover.sh          Generic CrossOver runtime + bottle helpers
  eso_paths.sh          ESO path resolution
  eso_runtime.sh        ESO launch, doctor, paths display
  eso_setup.sh          ESO bottle setup steps
  dune_paths.sh         Dune path resolution
  dune_runtime.sh       Dune launch, doctor, paths display
  dune_battleye.sh      BattlEye repair and BEService helpers
  dune_setup.sh         Dune bottle setup (AVX env, GUI steps)
scripts/
  eso/
    bottle.sh           Full workflow (task eso)
  dune/
    bottle.sh           Full workflow (task dune)
ties/                   Version-controlled CrossOver crosstie recipes (.tie)
taskfiles/eso.yaml
taskfiles/dune.yaml
tests/
```

## Development

| Task | Description |
|------|-------------|
| `task setup` | Install dev deps, pre-commit, bats |
| `task eso` | Full `The Elder Scrolls Online (Steam)` bottle workflow |
| `task eso:doctor` | Strict ESO bottle health check |
| `task eso:paths` | Resolved Mac/Windows/bottle paths |
| `task eso:status` | Bottle process status (eso64 / TTC / steam; argv + lsof-scoped) |
| `task eso:start` | Start Steam + ESO (`-applaunch 306130`) + TTC (detached) |
| `task eso:stop` | Clean bottle exit (`-- --keep-steam` for softer quit) |
| `task eso:launch:minion` | Launch native Minion.app (macOS) |
| `task eso:launch:ttc` | Launch Tamriel Trade Centre Client only |
| `task eso:fix-ttc-net` | Pin TTC hosts + probe host/Wine DNS (ErrorLog) |
| `task dune` | Full `Dune Awakening (Steam)` bottle workflow |
| `task dune:configure` | AVX env + GUI guidance only (no BattlEye fix) |
| `task dune:doctor` | Strict Dune bottle + BattlEye health check |
| `task dune:paths` | Resolved game/BattlEye/bottle paths |
| `task dune:fix-battleye` | Repair BattlEye ("Updating…" hang); `-- --full-reset` deletes game BE dir |
| `task dune:verify-steam` | Steam integrity verify after full reset |
| `task dune:launch:steam` | Launch Steam in the bottle |
| `task dune:launch:game` | Launch via BattlEye wrapper |
| `task timemachine` | Exclude `~/Library/Application Support/CrossOver/Bottles` from Time Machine |
| `task timemachine:status` | Show whether the CrossOver bottles directory is excluded |
| `task check` | lint + format:check + test |

## Related ESO projects

- [eso-rule-engine](https://github.com/solaegis/eso-rule-engine) — in-game rule engine addon
- [rustling](https://github.com/solaegis/rustling) — native addon manager

## License

MIT
