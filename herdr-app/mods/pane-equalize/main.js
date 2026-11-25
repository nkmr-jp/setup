// Gives every pane of a tab the same share whenever the tab
// gains or loses a pane, and on the "pane-equalize.now" key. Herdr's split
// halves the split pane, and a closed pane's share goes to its neighbor.
import { View, div } from "gpui-kit";
import { appHome, checking, exec, focused, nextCommand, panes, run } from "herdr";

export default class PaneEqualize extends View {
  init(_props, cx) {
    this.counts = null;
    if (checking()) return;
    cx.spawn(async () => {
      for (;;) {
        if ((await nextCommand()) === "now") this.equalize(focused()?.tab);
      }
    });
    // The block is hidden, so render() is not a reliable trigger; counting
    // panes is cheap.
    cx.timer.every(500, () => this.watch());
  }

  // Only a changed pane count triggers, so dragged dividers stay where they are.
  watch() {
    const counts = {};
    for (const p of panes()) counts[p.tab] = (counts[p.tab] ?? 0) + 1;
    const before = this.counts;
    this.counts = counts;
    if (!before || checking()) return;
    for (const [tab, n] of Object.entries(counts)) {
      if (before[tab] !== undefined && n !== before[tab]) this.equalize(tab);
    }
  }

  async equalize(tab) {
    // Remote tabs ("machine/id") live in another core's document.
    if (!tab || tab.includes("/")) return;
    const r = await exec("python3", [`${appHome()}/mods/pane-equalize/children.py`, tab]);
    if (r.code !== 0) return console.log(`pane-equalize: ${r.stderr}`);
    for (const id of JSON.parse(r.stdout)) run("layout.resize", { id, weight: 1 });
  }

  render() {
    return div();
  }
}
