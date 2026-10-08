import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { RecencyTracker } from "../src/recency.js";

describe("recency of tabs", () => {
  it("stamps a tab that is active at first sight, and leaves unseen background tabs without a time", () => {
    const tracker = new RecencyTracker();
    tracker.observe([{ id: "a", active: true }, { id: "b", active: false }], 1_000);
    assert.equal(tracker.lastActive("a"), 1_000);
    assert.equal(tracker.lastActive("b"), undefined);
  });

  it("stamps a tab when it becomes active, not while it stays active", () => {
    const tracker = new RecencyTracker();
    tracker.observe([{ id: "a", active: true }, { id: "b", active: false }], 1_000);
    tracker.observe([{ id: "a", active: true }, { id: "b", active: false }], 2_000);
    assert.equal(tracker.lastActive("a"), 1_000);
    tracker.observe([{ id: "a", active: false }, { id: "b", active: true }], 3_000);
    assert.equal(tracker.lastActive("b"), 3_000);
    assert.equal(tracker.lastActive("a"), 1_000);
    tracker.observe([{ id: "a", active: true }, { id: "b", active: false }], 4_000);
    assert.equal(tracker.lastActive("a"), 4_000);
  });

  it("forgets tabs that are gone, so a returning tab starts without an old time", () => {
    const tracker = new RecencyTracker();
    tracker.observe([{ id: "a", active: true }], 1_000);
    tracker.observe([], 2_000);
    assert.equal(tracker.lastActive("a"), undefined);
    tracker.observe([{ id: "a", active: false }], 3_000);
    assert.equal(tracker.lastActive("a"), undefined);
  });

  it("counts regaining window focus as use of the focused tab only", () => {
    const tracker = new RecencyTracker();
    tracker.observe([{ id: "a", active: true }, { id: "b", active: false }], 1_000);
    tracker.touchActive(9_000);
    assert.equal(tracker.lastActive("a"), 9_000);
    assert.equal(tracker.lastActive("b"), undefined);
  });
});
