// pi-statusbar - structured status area for pi: a location/git/cost/time
// widget above the editor and a footer with a context meter, activity, and
// model chips. Design: .plans/main/pi-statusbar/PRD.md.
// This file currently carries only the widget shell (step 000).

import type { ExtensionAPI, ExtensionContext, Theme } from "@earendil-works/pi-coding-agent";

// Pull-based rendering: renderers read only this cached state, refreshed on
// session_start before any UI work.
let latestCtx: ExtensionContext | undefined;
let sessionStart = 0;

function renderWidget(theme: Theme): string[] {
  return [theme.fg("dim", "pi-statusbar")];
}

export default function piStatusbar(pi: ExtensionAPI): void {
  pi.on("session_start", (_event, ctx) => {
    latestCtx = ctx;
    sessionStart = Date.now();
    if (!ctx.hasUI) return;
    ctx.ui.setWidget(
      "pi-statusbar",
      (_tui, theme) => ({
        render: () => renderWidget(theme),
        // Nothing cached yet; later steps invalidate cached state on theme change.
        invalidate: () => {},
      }),
      { placement: "aboveEditor" },
    );
  });
}
