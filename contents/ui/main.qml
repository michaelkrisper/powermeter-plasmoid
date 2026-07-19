import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.ksysguard.sensors as Sensors

PlasmoidItem {
    id: root

    // all values come from the shared ksystemstats daemon (DBus-activated,
    // native, also used by plasma-systemmonitor) — no process spawns, no shell
    readonly property real watts: rate.value === undefined ? -1 : Math.abs(rate.value)
    readonly property bool charging: (rate.value || 0) > 0
    readonly property int percent: pct.value === undefined ? -1 : pct.value
    readonly property real tempC: (temp.value || 0) > 0 ? temp.value : -1
    readonly property real cpuPct: cpu.value === undefined ? -1 : cpu.value
    property real hoursLeft: -1   // remaining time in hours; <0 = unknown
    property bool prevCharging: false
    property var powerHist: []    // last chargeRate samples (W) for smoothing
    readonly property int powerHistMax: 12   // 12 × 5s ≈ last minute
    readonly property real powerLawExp: 1.2  // weight = rank^exp; higher = more responsive (less damping)
    readonly property int tick: 5000

    Sensors.Sensor { id: cpu;    sensorId: "cpu/all/usage";                        updateRateLimit: root.tick }
    Sensors.Sensor { id: temp;   sensorId: "cpu/all/averageTemperature";           updateRateLimit: root.tick }
    Sensors.Sensor { id: pct;    sensorId: "power/battery_BAT0/chargePercentage";  updateRateLimit: root.tick }
    Sensors.Sensor { id: charge; sensorId: "power/battery_BAT0/charge";            updateRateLimit: root.tick }
    Sensors.Sensor { id: cap;    sensorId: "power/battery_BAT0/capacity";          updateRateLimit: root.tick }
    Sensors.Sensor {
        id: rate; sensorId: "power/battery_BAT0/chargeRate"; updateRateLimit: root.tick
        onValueChanged: root.updateRemaining()
    }

    // remaining time from a power-law weighted draw over the last minute:
    // newer samples weigh more (rank^exp), so it tracks recent changes but
    // still ignores the per-tick jitter of the instantaneous rate
    function updateRemaining() {
        var r = rate.value
        var en = charge.value    // Wh
        var ef = cap.value       // Wh (last full capacity)
        if (r === undefined || en === undefined || Math.abs(r) < 0.5) {
            root.powerHist = []
            root.hoursLeft = -1
            return
        }
        var chg = r > 0
        if (chg !== root.prevCharging) root.powerHist = []   // mode flip → drop stale samples
        root.prevCharging = chg
        var h = root.powerHist
        h.push(Math.abs(r))
        while (h.length > root.powerHistMax) h.shift()
        root.powerHist = h
        var num = 0, den = 0
        for (var i = 0; i < h.length; i++) {
            var w = Math.pow(i + 1, root.powerLawExp)   // i=0 oldest … newest heaviest
            num += h[i] * w; den += w
        }
        var avg = num / den                              // W; Wh / W = h
        root.hoursLeft = chg ? ((ef || 0) - en) / avg : en / avg
    }

    // set after the component tree exists, so it never resolves to null
    Component.onCompleted: root.preferredRepresentation = root.compactRepresentation

    // left-pad with spaces to a fixed length; with a monospace font this keeps
    // every value the same pixel width so the readout never jitters
    function pad(s, n) { s = "" + s; while (s.length < n) s = " " + s; return s }

    function fmtTime(h) {
        if (h < 0 || !isFinite(h)) return "—"
        var m = Math.round(h * 60 / 5) * 5   // round to 5-minute precision
        var hh = Math.floor(m / 60), mm = m % 60
        if (hh <= 0) return "≈" + mm + "min"
        return "≈" + hh + "h" + (mm < 10 ? "0" : "") + mm + "min"
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

            // remaining time — top, right-aligned
            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignRight
                horizontalAlignment: Text.AlignRight
                text: root.fmtTime(root.hoursLeft)
                color: "white"
                font.pixelSize: Math.max(8, Math.round(comp.height * 0.42))
                font.bold: true
            }

            // 2x2 grid: cpu | temp · watt | charge
            GridLayout {
                Layout.alignment: Qt.AlignRight
                columns: 2
                rowSpacing: 2
                columnSpacing: 6
                PlasmaComponents.Label {
                    text: root.cpuPct < 0 ? root.pad("…", 4) : root.pad(Math.round(root.cpuPct) + "%", 4)
                    color: "white"; font.pointSize: 8; font.family: "monospace"
                    horizontalAlignment: Text.AlignRight; Layout.alignment: Qt.AlignRight
                }
                PlasmaComponents.Label {
                    text: root.tempC < 0 ? root.pad("—", 5) : root.pad(Math.round(root.tempC) + "°C", 5)
                    color: "white"; font.pointSize: 8; font.family: "monospace"
                    horizontalAlignment: Text.AlignRight; Layout.alignment: Qt.AlignRight
                }
                PlasmaComponents.Label {
                    text: root.watts < 0 ? root.pad("…W", 4) : root.pad(Math.round(root.watts) + "W", 4)
                    color: "white"; font.pointSize: 8; font.family: "monospace"
                    horizontalAlignment: Text.AlignRight; Layout.alignment: Qt.AlignRight
                }
                PlasmaComponents.Label {
                    text: root.percent < 0 ? root.pad("—", 4) : root.pad(root.percent + "%", 4)
                    color: "white"; font.pointSize: 8; font.family: "monospace"
                    horizontalAlignment: Text.AlignRight; Layout.alignment: Qt.AlignRight
                }
            }
        }
    }

    fullRepresentation: ColumnLayout {
        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            text: root.fmtTime(root.hoursLeft)
            color: "white"; font.pointSize: 18; font.bold: true
        }
        GridLayout {
            Layout.alignment: Qt.AlignHCenter
            columns: 2
            rowSpacing: 4
            columnSpacing: 12
            PlasmaComponents.Label { text: root.cpuPct < 0 ? "…%" : Math.round(root.cpuPct) + "%"
                color: "white"; font.pointSize: 11; font.family: "monospace"
                horizontalAlignment: Text.AlignRight; Layout.alignment: Qt.AlignRight }
            PlasmaComponents.Label { text: root.tempC < 0 ? "—" : Math.round(root.tempC) + "°C"
                color: "white"; font.pointSize: 11; font.family: "monospace"
                horizontalAlignment: Text.AlignRight; Layout.alignment: Qt.AlignRight }
            PlasmaComponents.Label { text: root.watts < 0 ? "…W" : Math.round(root.watts) + "W"
                color: "white"; font.pointSize: 11; font.family: "monospace"
                horizontalAlignment: Text.AlignRight; Layout.alignment: Qt.AlignRight }
            PlasmaComponents.Label { text: root.percent < 0 ? "—" : root.percent + "%"
                color: "white"; font.pointSize: 11; font.family: "monospace"
                horizontalAlignment: Text.AlignRight; Layout.alignment: Qt.AlignRight }
        }
    }
}
