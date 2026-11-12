.pragma library
// Pure helpers shared by main.qml; kept free of QML types so they run under node --test.

// Left-pad to a fixed length; with a monospace font every value keeps the same
// pixel width, so the readout never jitters.
function pad(s, n) { return String(s).padStart(n) }

// Format hours as "≈2h15min" at 5-minute precision; "—" when unknown (<0 or non-finite).
function fmtTime(h) {
    if (!(h >= 0) || !isFinite(h)) return "—"
    var m = Math.round(h * 60 / 5) * 5, hh = Math.floor(m / 60), mm = m % 60
    return "≈" + (hh > 0 ? hh + "h" + (mm < 10 ? "0" : "") : "") + mm + "min"
}

// Append x and drop the oldest entries beyond max (mutates and returns hist).
function pushSample(hist, x, max) {
    hist.push(x)
    if (hist.length > max) hist.splice(0, hist.length - max)
    return hist
}

// Power-law weighted mean: sample i (0 = oldest) weighs (i+1)^exp, so recent
// samples dominate while per-tick jitter is still damped. NaN for an empty list.
function weightedMean(xs, exp) {
    var num = 0, den = 0
    for (var i = 0; i < xs.length; i++) {
        var w = Math.pow(i + 1, exp)
        num += xs[i] * w; den += w
    }
    return num / den
}

// Hours until empty (discharging) or full (charging); energies in Wh, power in W.
function hoursLeft(watts, chargeWh, capacityWh, charging) {
    return (charging ? (capacityWh || 0) - chargeWh : chargeWh) / watts
}
