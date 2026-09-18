// pi-statusbar - structured status area for pi: a location/git/cost/time
// widget above the editor and a footer with a context meter, activity, and
// model chips. Design: .plans/main/pi-statusbar/PRD.md.
// Currently implemented: the top row widget (dir, cost, elapsed time).

import type {
  ExtensionAPI,
  ExtensionContext,
  SessionEntry,
  Theme,
} from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import { isAbsolute, relative, resolve, sep } from "node:path";

// ── Icons ──
// Nerd Font glyphs by default; flip to the ASCII set on terminals without a
// patched font. Later steps consume the entries this step does not render.
const useNerdFont = true;

const NERD_FONT_ICONS = {
  folder: "\uF07B",
  branch: "\uF418",
  provider: "\uF2DB",
  think: "\uF0D0",
  clock: "\uF017",
  cost: "\uF155",
  up: "\u2191",
  dot: "\u25CF",
} as const;

const ASCII_ICONS = {
  folder: "~",
  branch: "git:",
  provider: "api:",
  think: "th:",
  clock: "@",
  cost: "$",
  up: "^",
  dot: "*",
} as const;

const icons = useNerdFont ? NERD_FONT_ICONS : ASCII_ICONS;

// ── State ──
// Pull-based rendering: renderers read only this cached state, refreshed on
// session_start before any UI work.
let latestCtx: ExtensionContext | undefined;
let sessionStart = 0;

// ── Formatting ──

// Shorten a cwd to `~/…` inside $HOME, absolute path otherwise. Same rules
// as context-bar.ts (single-file convention: no imports between extensions).
function shortenCwd(cwd: string, home: string | undefined): string {
  if (!home) return cwd;
  const resolvedCwd = resolve(cwd);
  const resolvedHome = resolve(home);
  const relativeToHome = relative(resolvedHome, resolvedCwd);
  const isInsideHome =
    relativeToHome === "" ||
    (relativeToHome !== ".." && !relativeToHome.startsWith(`..${sep}`) && !isAbsolute(relativeToHome));
  if (!isInsideHome) return cwd;
  return relativeToHome === "" ? "~" : `~${sep}${relativeToHome}`;
}

// `12m` under an hour, `1h02` at or over an hour.
function formatElapsed(ms: number): string {
  const totalMinutes = Math.floor(ms / 60_000);
  if (totalMinutes < 60) return `${totalMinutes}m`;
  return `${Math.floor(totalMinutes / 60)}h${String(totalMinutes % 60).padStart(2, "0")}`;
}

// Dollar amount with two decimals.
function formatCost(cost: number): string {
  return `$${cost.toFixed(2)}`;
}

// ── Data ──

// Session cost: usage.cost.total summed over the active branch - assistant
// replies, toolResult messages carrying usage, and branch summary/compaction
// entries carrying usage. 0 before the first usage.
function collectSessionCost(entries: SessionEntry[]): number {
  let cost = 0;
  for (const entry of entries) {
    if (entry.type === "message" && entry.message.role === "assistant") {
      cost += entry.message.usage.cost.total;
    } else if (entry.type === "message" && entry.message.role === "toolResult" && entry.message.usage) {
      cost += entry.message.usage.cost.total;
    } else if ((entry.type === "branch_summary" || entry.type === "compaction") && entry.usage) {
      cost += entry.usage.cost.total;
    }
  }
  return cost;
}

// ── Rendering ──
// Pure string builders over cached state only; never throw on missing data.

// Top row: folder icon + ~-shortened cwd left, session cost and elapsed time
// right, full-width rule as the widget's last line.
function renderTopRow(width: number, theme: Theme): string[] {
  const rule = theme.fg("dim", "─".repeat(Math.max(0, width)));
  const ctx = latestCtx;
  if (!ctx) return [rule];

  const cwd = shortenCwd(ctx.sessionManager.getCwd(), process.env.HOME || process.env.USERPROFILE);
  const left = theme.fg("dim", `${icons.folder} ${cwd}`);
  const cost = theme.fg("dim", `${icons.cost} ${formatCost(collectSessionCost(ctx.sessionManager.getBranch()))}`);
  const time = theme.fg("dim", `${icons.clock} ${formatElapsed(Math.max(0, Date.now() - sessionStart))}`);
  const right = `${cost} ${time}`;

  // Right group ends flush at the width; beyond that, hard-clip like the
  // validated prototype instead of moving the right group.
  const pad = width - visibleWidth(left) - visibleWidth(right);
  const line = pad >= 1 ? left + " ".repeat(pad) + right : truncateToWidth(`${left} ${right}`, width, "");
  return [line, rule];
}

export default function piStatusbar(pi: ExtensionAPI): void {
  pi.on("session_start", (_event, ctx) => {
    latestCtx = ctx;
    sessionStart = Date.now();
    if (!ctx.hasUI) return;
    ctx.ui.setWidget(
      "pi-statusbar",
      (_tui, theme) => ({
        render: (width: number) => renderTopRow(width, theme),
        // Stateless renderer: pi re-invokes the factory on theme change.
        invalidate: () => {},
      }),
      { placement: "aboveEditor" },
    );
  });
}
