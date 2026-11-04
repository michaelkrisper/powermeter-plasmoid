// Pure helpers for the widget, free of QML types so the tests can run them under Node.

// Mean of samples (oldest first) weighted by rank^exponent, so newer samples count more.
function weightedAverage(samples, exponent) {
    var num = 0, den = 0
    for (var i = 0; i < samples.length; i++) {
        var w = Math.pow(i + 1, exponent)
        num += samples[i] * w; den += w
    }
    return num / den
}

// Hours until full while charging, until empty otherwise (Wh / W = h).
function remainingHours(avgWatts, energyWh, capacityWh, charging) {
    return charging ? ((capacityWh || 0) - energyWh) / avgWatts : energyWh / avgWatts
}

// Left-pad with spaces to a fixed length; with a monospace font this keeps
// every value the same pixel width so the readout never jitters.
function pad(s, n) {
    s = "" + s
    while (s.length < n) s = " " + s
    return s
}

function formatTime(h) {
    if (h < 0 || !isFinite(h)) return "—"
    var m = Math.round(h * 60 / 5) * 5   // round to 5-minute precision
    var hh = Math.floor(m / 60), mm = m % 60
    if (hh <= 0) return "≈" + mm + "min"
    return "≈" + hh + "h" + (mm < 10 ? "0" : "") + mm + "min"
}
