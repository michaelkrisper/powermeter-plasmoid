# CLAUDE.md

Power Meter is a KDE Plasma 6 panel widget (plasmoid, Id `com.local.powermeter`) showing
battery time left, CPU load and temperature, power draw and charge. Plain QML plus one JS
helper file, no build step. It is installed by cloning the repo into
`~/.local/share/plasma/plasmoids/com.local.powermeter` (directory name must equal the Id);
nothing deploys automatically.

## Commands

```sh
node --test      # unit tests for contents/ui/logic.js and metadata.json (no dependencies)
/usr/lib/qt6/bin/qmllint --import disable --unqualified disable contents/ui/main.qml   # as CI
kquitapp6 plasmashell; nohup plasmashell >/dev/null 2>&1 &   # reload after a change
rm -rf ~/.cache/plasmashell/qmlcache ~/.cache/org.kde.plasmashell   # if QML changes do not show
```

CI runs the tests on Node 26 and `qmllint`. The KDE QML modules are not installable on
the runner, so qmllint cannot catch missing imports or KDE API mistakes; only a running
Plasma shell does (check `journalctl --user` for QML errors after the restart).

## Architecture

- `contents/ui/main.qml`: `PlasmoidItem` with compact and full representations. All values
  come from `org.kde.ksysguard.sensors` (`Sensors.Sensor`, shared ksystemstats daemon):
  `cpu/all/usage`, `cpu/all/averageTemperature`,
  `power/battery_BAT0/{chargeRate,charge,capacity,chargePercentage}`. `chargeRate` < 0
  means discharging. Update rate 5 s (`tick`, `updateRateLimit`).
- `contents/ui/logic.js`: pure helpers (power-law weighted average of the last 12 rate
  samples, remaining hours, padding, time formatting), free of QML types so Node can run
  them. Put new logic here, with a test in `test/logic.test.js`.
- `metadata.json`: KPackage metadata; the tests check its shape and Id.

## Rules

- Spawn no processes and add no animations: the widget once forked `/bin/sh` per tick
  and tweened values, and both cost measurable power. Labels bind straight to sensor values.
- Values are padded to fixed width in a monospace font so the panel never jitters.
- `power/battery_BAT0` is hardcoded on purpose (single target machine); keep it unless
  making it configurable.
- Never edit `KPlugin.Version` in `metadata.json` (frozen at 1.2); versions come from tags.

## Workflow

- Every change starts with a GitHub issue. Branch `<issue>-<slug>` from `main`,
  open a PR with `Closes #<issue>`. Never push to `main` directly.
- PRs auto-merge (squash) once CI and the "Linked ticket" check pass; drafts are not merged.
- Versions exist only as git tags `vX.Y.Z`. Every merge to `main` tags the next patch;
  never edit version numbers in files. Minor/major releases: Actions -> Release.
- Nothing deploys automatically; installs update with `git pull` in the plasmoids
  directory and a plasmashell restart.
- Details: CONTRIBUTING.md.
