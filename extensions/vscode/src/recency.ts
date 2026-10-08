/**
 * Remembers when each tab last became the focused one. VS Code reports no such time, so it is kept
 * here, and it starts empty: a tab nobody has focused since the window opened has no time and is
 * listed after those that do, which is more honest than inventing one.
 */
export class RecencyTracker {
  private readonly wasActive = new Map<string, boolean>();
  private readonly times = new Map<string, number>();

  /** Call with every tab on each snapshot; a tab turning active, or active at first sight, is stamped. */
  observe(tabs: ReadonlyArray<{ id: string; active: boolean }>, nowMs: number): void {
    const present = new Set(tabs.map((tab) => tab.id));
    for (const tab of tabs) {
      if (tab.active && this.wasActive.get(tab.id) !== true) this.times.set(tab.id, nowMs);
      this.wasActive.set(tab.id, tab.active);
    }
    for (const id of [...this.wasActive.keys()]) {
      if (present.has(id)) continue;
      this.wasActive.delete(id);
      this.times.delete(id);
    }
  }

  /** The window regained focus: its focused tab was used just now even though it did not change. */
  touchActive(nowMs: number): void {
    for (const [id, active] of this.wasActive) if (active) this.times.set(id, nowMs);
  }

  lastActive(id: string): number | undefined {
    return this.times.get(id);
  }
}
