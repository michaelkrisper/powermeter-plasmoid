// Loads contents/ui/logic.js (a QML ".pragma library" script) into a sandbox and tests its pure helpers.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";

const src = readFileSync(new URL("../contents/ui/logic.js", import.meta.url), "utf8");
const L = vm.createContext({});
vm.runInContext(src.replace(/^\.pragma library$/m, ""), L);

test("pad left-pads to a fixed width and leaves longer strings intact", () => {
    assert.equal(L.pad("5%", 4), "  5%");
    assert.equal(L.pad(42, 3), " 42");
    assert.equal(L.pad("100%", 3), "100%");
});

test("fmtTime renders unknown values as a dash", () => {
    for (const h of [-1, -0.01, NaN, Infinity, -Infinity]) assert.equal(L.fmtTime(h), "—");
});

test("fmtTime rounds to 5-minute precision", () => {
    assert.equal(L.fmtTime(0), "≈0min");
    assert.equal(L.fmtTime(2 / 60), "≈0min");
    assert.equal(L.fmtTime(3 / 60), "≈5min");
    assert.equal(L.fmtTime(0.5), "≈30min");
    assert.equal(L.fmtTime(1), "≈1h00min");
    assert.equal(L.fmtTime(2.25), "≈2h15min");
    assert.equal(L.fmtTime(59 / 60), "≈1h00min");   // rounds up across the hour boundary
    assert.equal(L.fmtTime(10 + 52 / 60), "≈10h50min");
});

test("pushSample keeps only the newest max samples, in order", () => {
    const h = [];
    for (let i = 1; i <= 5; i++) L.pushSample(h, i, 3);
    assert.deepEqual([...h], [3, 4, 5]);
    assert.equal(L.pushSample(h, 6, 3), h);   // mutates in place
});

test("weightedMean is exact for constant input and favours recent samples", () => {
    assert.equal(L.weightedMean([7, 7, 7], 1.2), 7);
    assert.equal(L.weightedMean([4], 1.2), 4);
    assert.equal(L.weightedMean([0, 10], 1), 10 * 2 / 3);
    const m = L.weightedMean([10, 20], 1.2);
    assert.ok(m > 15 && m < 20);
    assert.ok(Number.isNaN(L.weightedMean([], 1.2)));
});

test("weightedMean with exponent 0 is the plain average", () => {
    assert.equal(L.weightedMean([1, 2, 3, 6], 0), 3);
});

test("hoursLeft: discharging divides remaining energy, charging the missing energy", () => {
    assert.equal(L.hoursLeft(10, 40, 60, false), 4);
    assert.equal(L.hoursLeft(20, 40, 60, true), 1);
    assert.equal(L.hoursLeft(20, 40, undefined, true), -2);   // unknown capacity → negative → shown as "—"
    assert.equal(L.fmtTime(L.hoursLeft(20, 40, undefined, true)), "—");
});
