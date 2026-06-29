# Power Meter

A minimal Plasma 6 panel widget (plasmoid) showing live system power and load.

Compact panel layout:

```
   2:45        ← battery time left (large)
 12%   62°C    ← CPU load · CPU package temperature
 27 W  84 %    ← power draw · charge level
```

On AC a `⚡` prefix is shown and the time counts toward full.

## Data sources

Read once per tick via a single shell process (no `cat` forks):

- `/sys/class/power_supply/BAT0/{power_now,energy_now,energy_full,capacity,status}` — power, remaining time, charge
- `/sys/class/thermal/thermal_zone0/temp` — CPU package temperature (`x86_pkg_temp`)
- `/proc/stat` — CPU load, computed as the busy/total jiffy delta between ticks

Update interval: 5 s. CPU load needs two ticks before the first value appears.

## Requirements

- KDE Plasma 6 (`X-Plasma-API-Minimum-Version` 6.0)
- A Linux system exposing `/sys/class/power_supply/BAT0`, `/sys/class/thermal/thermal_zone0` and `/proc/stat`

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

## Notes

- Battery path `BAT0` and thermal zone `thermal_zone0` are hardcoded; adjust in
  `contents/ui/main.qml` for other hardware.
- Built and tuned on a MacBook Pro 11,1 running Fedora KDE (Plasma 6).
