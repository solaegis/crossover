# CrossOver crossties (`.tie`)

Version-controlled [CrossTie](https://www.codeweavers.com/) recipes for bottles managed by this repo.

Install from the repo copy (CrossOver → **Install a Windows Application** → select the `.tie` file, or double-click it in Finder):

| File | Bottle name | Purpose |
|------|-------------|---------|
| [`eso_steam.tie`](eso_steam.tie) | `The Elder Scrolls Online (Steam)` | Notes + Mac env for Steam ESO (bottle name = Crosstie `<name>`) |
| [`eso_standalone.tie`](eso_standalone.tie) | `The Elder Scrolls Online (Standalone)` | Non-Steam ESO via the Bethesda.net launcher |
| [`dune_steam.tie`](dune_steam.tie) | `Dune: Awakening (Steam)` | Steam + BattlEye install notes (bottle name = Crosstie `<name>`) |
| [`ttc_client.tie`](ttc_client.tie) | `The Elder Scrolls Online (Steam)` (existing) | Notes + .NET 4.8 only (Client.exe from Minion; no installer) |

Bottle defaults for `task eso` / `task dune` match these Crosstie `<name>` values.

**ESO Steam (greenfield):** Open `eso_steam.tie` — CrossOver creates **The Elder Scrolls Online (Steam)**. Then `task eso`.

**TTC:** Install Minion’s TamrielTradeCentre addon first. Open `ttc_client.tie` and select bottle **The Elder Scrolls Online (Steam)** (installs .NET 4.8 only — if CrossOver says “unknown installer type”, Cancel and use CrossOver → Install → **Microsoft .NET Framework 4.8** instead). Then `crossover eso fix-ttc-net`. Launch with `crossover eso launch ttc`.

Resolve a tracked tie path from scripts:

```bash
crossover_tie_path eso_steam
crossover_tie_path eso_standalone
crossover_tie_path ttc_client
# → …/crossover/ties/….tie
```
