const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");

const logic = {};
vm.runInNewContext(read("contents/ui/logic.js"), logic);

test("weightedAverage returns the value of constant samples", () => {
  assert.ok(Math.abs(logic.weightedAverage([12, 12, 12], 1.2) - 12) < 1e-9);
});

test("weightedAverage weighs newer samples more", () => {
  assert.ok(Math.abs(logic.weightedAverage([10, 20], 1) - 50 / 3) < 1e-9);
  assert.ok(logic.weightedAverage([10, 20, 30], 1.2) > 20);
  assert.ok(logic.weightedAverage([30, 20, 10], 1.2) < 20);
});

test("remainingHours divides stored energy by draw while discharging", () => {
  assert.equal(logic.remainingHours(10, 30, 50, false), 3);
});

test("remainingHours divides the missing energy by the rate while charging", () => {
  assert.equal(logic.remainingHours(10, 30, 50, true), 2);
});

test("remainingHours is negative, shown as unknown, without a capacity reading", () => {
  const hours = logic.remainingHours(10, 30, undefined, true);
  assert.ok(hours < 0);
  assert.equal(logic.formatTime(hours), "—");
});

test("pad left-pads to the width and never truncates", () => {
  assert.equal(logic.pad("7%", 4), "  7%");
  assert.equal(logic.pad(42, 4), "  42");
  assert.equal(logic.pad("100%", 4), "100%");
  assert.equal(logic.pad("12345", 4), "12345");
});

test("formatTime marks unknown values", () => {
  for (const hours of [-1, Infinity, NaN]) assert.equal(logic.formatTime(hours), "—");
});

test("formatTime shows minutes only below one hour", () => {
  assert.equal(logic.formatTime(0), "≈0min");
  assert.equal(logic.formatTime(0.5), "≈30min");
});

test("formatTime shows hours with zero-padded minutes", () => {
  assert.equal(logic.formatTime(2.75), "≈2h45min");
  assert.equal(logic.formatTime(1 + 5 / 60), "≈1h05min");
});

test("formatTime rounds to five minutes and carries into the hour", () => {
  assert.equal(logic.formatTime(0.99), "≈1h00min");
  assert.equal(logic.formatTime(1.04), "≈1h00min");
});

test("main.qml only calls helpers that logic.js defines", () => {
  const used = new Set([...read("contents/ui/main.qml").matchAll(/Logic\.(\w+)/g)].map((m) => m[1]));
  assert.ok(used.size > 0);
  for (const name of used) assert.equal(typeof logic[name], "function", name);
});

test("metadata.json describes a Plasma 6 applet", () => {
  const meta = JSON.parse(read("metadata.json"));
  assert.equal(meta.KPackageStructure, "Plasma/Applet");
  assert.match(meta.KPlugin.Id, /^[a-z0-9.]+$/);
  assert.match(meta.KPlugin.Version, /^\d+\.\d+/);
  assert.ok(meta.KPlugin.Name);
  assert.equal(meta["X-Plasma-API-Minimum-Version"].split(".")[0], "6");
});

test("README documents the install directory that matches the plugin id", () => {
  const { Id } = JSON.parse(read("metadata.json")).KPlugin;
  assert.ok(read("README.md").includes(`~/.local/share/plasma/plasmoids/${Id}`));
});
