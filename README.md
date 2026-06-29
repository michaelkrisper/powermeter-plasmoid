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

## Install

```sh
cp -r com.local.powermeter ~/.local/share/plasma/plasmoids/
kquitapp6 plasmashell; nohup plasmashell >/dev/null 2>&1 &
```

Then add **Power Meter** to a panel via *Add Widgets*.

If QML changes don't show up, clear the cache first:

```sh
rm -rf ~/.cache/plasmashell/qmlcache ~/.cache/org.kde.plasmashell
```

## Notes

- Battery path `BAT0` and thermal zone `thermal_zone0` are hardcoded; adjust in
  `contents/ui/main.qml` for other hardware.
- Built and tuned on a MacBook Pro 11,1 running Fedora KDE (Plasma 6).
