import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.ksysguard.sensors as Sensors
import "logic.js" as Logic

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
        root.powerHist = Logic.pushSample(root.powerHist, Math.abs(r), root.powerHistMax)
        root.hoursLeft = Logic.hoursLeft(Logic.weightedMean(root.powerHist, root.powerLawExp), en, ef, chg)
    }

    // set after the component tree exists, so it never resolves to null
    Component.onCompleted: root.preferredRepresentation = root.compactRepresentation

    toolTipMainText: root.watts < 0
        ? "Power meter"
        : (Math.round(root.watts) + " W " + (root.charging ? "(charging)" : "(battery)"))
    toolTipSubText: root.percent < 0
        ? ""
        : (root.percent + " % · " + Logic.fmtTime(root.hoursLeft) + (root.charging ? " to full" : " left"))

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
                text: Logic.fmtTime(root.hoursLeft)
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
                    text: root.cpuPct < 0 ? Logic.pad("…", 4) : Logic.pad(Math.round(root.cpuPct) + "%", 4)
                    font.pointSize: 8; font.family: "monospace"
                    horizontalAlignment: Text.AlignRight; Layout.alignment: Qt.AlignRight
                }
                PlasmaComponents.Label {
                    text: root.tempC < 0 ? Logic.pad("—", 5) : Logic.pad(Math.round(root.tempC) + "°C", 5)
                    font.pointSize: 8; font.family: "monospace"
                    horizontalAlignment: Text.AlignRight; Layout.alignment: Qt.AlignRight
                }
                PlasmaComponents.Label {
                    text: root.watts < 0 ? Logic.pad("…W", 4) : Logic.pad(Math.round(root.watts) + "W", 4)
                    font.pointSize: 8; font.family: "monospace"
                    horizontalAlignment: Text.AlignRight; Layout.alignment: Qt.AlignRight
                }
                PlasmaComponents.Label {
                    text: root.percent < 0 ? Logic.pad("—", 4) : Logic.pad(root.percent + "%", 4)
                    font.pointSize: 8; font.family: "monospace"
                    horizontalAlignment: Text.AlignRight; Layout.alignment: Qt.AlignRight
                }
            }
        }
    }

    fullRepresentation: ColumnLayout {
        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            text: Logic.fmtTime(root.hoursLeft)
            font.pointSize: 18; font.bold: true
        }
        GridLayout {
            Layout.alignment: Qt.AlignHCenter
            columns: 2
            rowSpacing: 4
            columnSpacing: 12
            PlasmaComponents.Label { text: root.cpuPct < 0 ? "…%" : Math.round(root.cpuPct) + "%"
                font.pointSize: 11; font.family: "monospace"
                horizontalAlignment: Text.AlignRight; Layout.alignment: Qt.AlignRight }
            PlasmaComponents.Label { text: root.tempC < 0 ? "—" : Math.round(root.tempC) + "°C"
                font.pointSize: 11; font.family: "monospace"
                horizontalAlignment: Text.AlignRight; Layout.alignment: Qt.AlignRight }
            PlasmaComponents.Label { text: root.watts < 0 ? "…W" : Math.round(root.watts) + "W"
                font.pointSize: 11; font.family: "monospace"
                horizontalAlignment: Text.AlignRight; Layout.alignment: Qt.AlignRight }
            PlasmaComponents.Label { text: root.percent < 0 ? "—" : root.percent + "%"
                font.pointSize: 11; font.family: "monospace"
                horizontalAlignment: Text.AlignRight; Layout.alignment: Qt.AlignRight }
        }
    }
}
