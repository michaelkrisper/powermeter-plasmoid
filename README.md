# Power Meter

[![CI](https://github.com/michaelkrisper/powermeter-plasmoid/actions/workflows/ci.yml/badge.svg)](https://github.com/michaelkrisper/powermeter-plasmoid/actions/workflows/ci.yml)
[![Version](https://img.shields.io/github/v/tag/michaelkrisper/powermeter-plasmoid?sort=semver&label=version)](https://github.com/michaelkrisper/powermeter-plasmoid/releases)
[![License: MIT](https://img.shields.io/github/license/michaelkrisper/powermeter-plasmoid)](LICENSE)
[![KDE Plasma 6](https://img.shields.io/badge/KDE%20Plasma-6-1d99f3)](https://kde.org/plasma-desktop/)
[![QML](https://img.shields.io/badge/language-QML-41cd52)](contents/ui/main.qml)

A minimal Plasma 6 panel widget (plasmoid) showing live system power and load.

Compact panel layout:

```
 ≈2h45min      ← battery time left (large)
  12%   62°C   ← CPU load · CPU temperature
  27W   84%    ← power draw · charge level
```

While charging, the time counts toward full.

## Data sources

All values come from the `ksystemstats` daemon (part of Plasma, shared with
plasma-systemmonitor) via the `org.kde.ksysguard.sensors` QML module — the
widget spawns no processes at all:

- `cpu/all/usage`, `cpu/all/averageTemperature` — CPU load and temperature
- `power/battery_BAT0/{chargeRate,charge,capacity,chargePercentage}` — power
  draw, remaining time, charge

Update interval: 5 s (`updateRateLimit`). Remaining time is a power-law
weighted average of the charge rate over the last minute.

## Requirements

- KDE Plasma 6 (`X-Plasma-API-Minimum-Version` 6.0) with `libksysguard`
  (ships with Plasma)

## Install

Clone into the local plasmoids directory:

```sh
git clone https://github.com/michaelkrisper/powermeter-plasmoid.git \
  ~/.local/share/plasma/plasmoids/com.local.powermeter
```

The target directory **must** be named `com.local.powermeter` (matches the `Id`
in `metadata.json`). Then restart the shell:

```sh
kquitapp6 plasmashell; nohup plasmashell >/dev/null 2>&1 &
```

Add **Power Meter** to a panel via right-click → *Add Widgets* → search "Power Meter".

### Update

```sh
git -C ~/.local/share/plasma/plasmoids/com.local.powermeter pull
rm -rf ~/.cache/plasmashell/qmlcache ~/.cache/org.kde.plasmashell
kquitapp6 plasmashell; nohup plasmashell >/dev/null 2>&1 &
```

### Uninstall

```sh
rm -rf ~/.local/share/plasma/plasmoids/com.local.powermeter
```

If QML changes don't show up, clear the cache first:

```sh
rm -rf ~/.cache/plasmashell/qmlcache ~/.cache/org.kde.plasmashell
```

## Development

Run the tests (Node.js, no dependencies):

```sh
node --test
```

They cover the pure helpers in `contents/ui/logic.js` (weighted draw, remaining
time, formatting) and check `metadata.json`. CI also runs `qmllint` on the QML.
The widget itself needs a running Plasma shell, so CI does not start it.
Every merge to `main` is tagged with the next patch version; bundled releases
with release notes come from the Release workflow.

## Contributing

Changes start with an issue and go through a pull request; see
[CONTRIBUTING](CONTRIBUTING.md).

## Notes

- The battery sensor id `power/battery_BAT0` is hardcoded; adjust in
  `contents/ui/main.qml` for other hardware.
- Built and tuned on a MacBook Pro 11,1 running Fedora KDE (Plasma 6).

## License

[MIT](LICENSE)
