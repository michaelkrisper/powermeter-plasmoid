import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.components as PlasmaComponents

PlasmoidItem {
    id: root

    property real watts: -1
    property bool charging: false
    property int percent: -1
    property real hoursLeft: -1   // remaining time in hours; <0 = unknown
    property real tempC: -1       // CPU package temperature in °C; <0 = unknown
    property real cpuPct: -1      // CPU usage 0..100; <0 = unknown (first tick)
    property int prevIdle: -1     // /proc/stat idle jiffies from last tick
    property int prevTotal: -1    // /proc/stat total jiffies from last tick

    // set after the component tree exists, so it never resolves to null
    Component.onCompleted: root.preferredRepresentation = root.compactRepresentation

    // left-pad with spaces to a fixed length; with a monospace font this keeps
    // every value the same pixel width so the readout never jitters
    function pad(s, n) { s = "" + s; while (s.length < n) s = " " + s; return s }

    function fmtTime(h) {
        if (h < 0 || !isFinite(h)) return "—"
        var m = Math.round(h * 60)
        return Math.floor(m / 60) + ":" + (m % 60 < 10 ? "0" : "") + (m % 60)
    }

    toolTipMainText: root.watts < 0
        ? "Power meter"
        : (Math.round(root.watts) + " W " + (root.charging ? "(charging)" : "(battery)"))
    toolTipSubText: root.percent < 0
        ? ""
        : (root.percent + " % · " + fmtTime(root.hoursLeft) + (root.charging ? " to full" : " left"))

    compactRepresentation: Item {
        id: comp
        Layout.minimumWidth: col.implicitWidth + 8
        Layout.preferredWidth: col.implicitWidth + 8

        ColumnLayout {
            id: col
            anchors.centerIn: parent
            spacing: 0

            // remaining time — biggest, top, centered
            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignHCenter
                text: (root.charging ? "⚡ " : "") + fmtTime(root.hoursLeft)
                color: "white"
                font.pixelSize: Math.max(8, Math.round(comp.height * 0.5))
                font.bold: true
            }

            // 2x2 grid below: cpu% | temp · watt | akku%
            GridLayout {
                Layout.alignment: Qt.AlignHCenter
                columns: 2
                rowSpacing: 0
                columnSpacing: 6
                PlasmaComponents.Label {
                    text: root.cpuPct < 0 ? root.pad("…", 4) : root.pad(Math.round(root.cpuPct) + "%", 4)
                    color: "white"; opacity: 0.8; font.pointSize: 6; font.family: "monospace"
                    horizontalAlignment: Text.AlignRight; Layout.alignment: Qt.AlignRight
                }
                PlasmaComponents.Label {
                    text: root.tempC < 0 ? root.pad("—", 5) : root.pad(Math.round(root.tempC) + "°C", 5)
                    color: "white"; opacity: 0.8; font.pointSize: 6; font.family: "monospace"
                    horizontalAlignment: Text.AlignRight; Layout.alignment: Qt.AlignRight
                }
                PlasmaComponents.Label {
                    text: root.watts < 0 ? root.pad("…W", 4) : root.pad(Math.round(root.watts) + "W", 4)
                    color: "white"; opacity: 0.8; font.pointSize: 6; font.family: "monospace"
                    horizontalAlignment: Text.AlignRight; Layout.alignment: Qt.AlignRight
                }
                PlasmaComponents.Label {
                    text: root.percent < 0 ? root.pad("—", 4) : root.pad(root.percent + "%", 4)
                    color: "white"; opacity: 0.8; font.pointSize: 6; font.family: "monospace"
                    horizontalAlignment: Text.AlignRight; Layout.alignment: Qt.AlignRight
                }
            }
        }
    }

    fullRepresentation: ColumnLayout {
        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            text: (root.charging ? "⚡ " : "") + fmtTime(root.hoursLeft)
            color: "white"
            font.pointSize: 18
            font.bold: true
        }
        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            text: (root.cpuPct < 0 ? "…%" : Math.round(root.cpuPct) + "%")
                + (root.tempC < 0 ? "" : "   " + Math.round(root.tempC) + "°C")
            color: "white"
            opacity: 0.8
            font.pointSize: 9
            font.family: "monospace"
        }
        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            text: (root.watts < 0 ? "…W" : Math.round(root.watts) + "W")
                + (root.percent < 0 ? "" : "   " + root.percent + "%")
            color: "white"
            font.pointSize: 11
            font.family: "monospace"
        }
    }

    // 'read' is a shell builtin → only the shell process is spawned per tick,
    // no extra cat forks. Keeps wakeup cost minimal.
    readonly property string cmd:
        "read P  < /sys/class/power_supply/BAT0/power_now  2>/dev/null;" +
        "read EN < /sys/class/power_supply/BAT0/energy_now 2>/dev/null;" +
        "read EF < /sys/class/power_supply/BAT0/energy_full 2>/dev/null;" +
        "read C  < /sys/class/power_supply/BAT0/capacity   2>/dev/null;" +
        "read S  < /sys/class/power_supply/BAT0/status     2>/dev/null;" +
        "read T  < /sys/class/thermal/thermal_zone0/temp   2>/dev/null;" +
        "read _ CU CN CS CI CW CQ CSQ R < /proc/stat 2>/dev/null;" +
        "IDLE=$((CI+CW)); TOTAL=$((CU+CN+CS+CI+CW+CQ+CSQ));" +
        "printf '%s %s %s %s %s %s %s %s' \"${P:-0}\" \"${EN:-0}\" \"${EF:-0}\" \"${C:--1}\" \"${S:-?}\" \"${T:--1}\" \"${IDLE:--1}\" \"${TOTAL:--1}\""

    P5Support.DataSource {
        id: exe
        engine: "executable"
        connectedSources: [root.cmd]
        interval: 5000
        onNewData: function(source, data) {
            var p = (data["stdout"] || "").trim().split(/\s+/)
            var power = parseInt(p[0]) || 0          // µW
            var en    = parseInt(p[1]) || 0          // µWh
            var ef    = parseInt(p[2]) || 0          // µWh
            root.watts    = power / 1e6
            root.percent  = parseInt(p[3])
            if (isNaN(root.percent)) root.percent = -1
            root.charging = (p[4] === "Charging" || p[4] === "Full")
            if (power > 0)
                root.hoursLeft = root.charging ? (ef - en) / power : en / power
            else
                root.hoursLeft = -1
            var t = parseInt(p[5])          // millidegrees C
            root.tempC = (isNaN(t) || t < 0) ? -1 : t / 1000
            var idle = parseInt(p[6]), total = parseInt(p[7])   // jiffies
            if (!isNaN(idle) && !isNaN(total) && root.prevTotal >= 0) {
                var dt = total - root.prevTotal
                if (dt > 0)
                    root.cpuPct = Math.max(0, Math.min(100, (1 - (idle - root.prevIdle) / dt) * 100))
            }
            if (!isNaN(idle) && !isNaN(total)) { root.prevIdle = idle; root.prevTotal = total }
        }
    }
}
