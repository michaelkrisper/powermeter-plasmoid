# Power Meter

A minimal KDE Plasma 6 panel widget showing battery time left, CPU load and temperature, power draw and charge.

[![CI](https://github.com/michaelkrisper/powermeter-plasmoid/actions/workflows/ci.yml/badge.svg)](https://github.com/michaelkrisper/powermeter-plasmoid/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Plasma 6](https://img.shields.io/badge/KDE_Plasma-6-1d99f3.svg)](https://kde.org/plasma-desktop/)
[![QML](https://img.shields.io/badge/QML-Qt_6-41cd52.svg)](https://doc.qt.io/qt-6/qmlapplications.html)

## Features

- Compact four-value readout plus a large remaining-time line, sized for a panel
- Remaining time to empty or, while charging, to full, smoothed over the last minute
- Fixed-width monospace values, so the panel never jitters as numbers change
- Zero process spawns: everything is read from the `ksystemstats` daemon
- Follows the Plasma colour scheme; user interface text is English

Compact panel layout:

```
   2:45        ← battery time left (large)
 12%   62°C    ← CPU load · CPU package temperature
 27 W  84 %    ← power draw · charge level
```

While charging, the time counts toward full.

## How it works

All values come from the `ksystemstats` daemon (part of Plasma, shared with
plasma-systemmonitor) via the `org.kde.ksysguard.sensors` QML module — the
widget spawns no processes at all:

- `cpu/all/usage`, `cpu/all/averageTemperature` — CPU load and temperature
- `power/battery_BAT0/{chargeRate,charge,capacity,chargePercentage}` — power
  draw, remaining time, charge

Update interval: 5 s (`updateRateLimit`). On every charge-rate update the
absolute rate is appended to a 12-sample ring (about one minute); sample *i*
(oldest = 1) is weighted by *i*^1.2, so recent changes show up quickly while
per-tick jitter is damped. Remaining time is `charge / rate` when discharging
and `(capacity − charge) / rate` when charging, rounded to 5 minutes. The
history is reset when the battery switches between charging and discharging
or the rate drops below 0.5 W.

Layout and sensor bindings live in `contents/ui/main.qml`; the pure
formatting and estimation helpers live in `contents/ui/logic.js`
(a `.pragma library` script) so they can be unit-tested outside Plasma.

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

Requirements: Node.js 20+ for the tests; Qt 6 `qmllint` and `jq` for linting
(Ubuntu: `qt6-declarative-dev-tools`, `jq`).

```sh
node --test                                           # unit tests for contents/ui/logic.js
/usr/lib/qt6/bin/qmllint contents/ui/*.qml contents/ui/*.js   # QML/JS lint
jq -e . metadata.json                                 # metadata is valid JSON
```

Plasma 6 QML modules are not available on the Ubuntu CI runner, so CI runs
`qmllint` with type-resolution checks downgraded to info: syntax errors fail
the build, unresolved Plasma types do not. See `.github/workflows/ci.yml` for
the exact steps.

To try changes, install via the clone above (or symlink your working copy to
`~/.local/share/plasma/plasmoids/com.local.powermeter`), clear the QML cache
and restart `plasmashell`.

## Notes

- The battery sensor id `power/battery_BAT0` is hardcoded; adjust in
  `contents/ui/main.qml` for other hardware.
- Built and tuned on a MacBook Pro 11,1 running Fedora KDE (Plasma 6).

## License

[MIT](LICENSE) © Michael Krisper
