// pi-statusbar - structured status area for pi: a location/git/cost/time
// widget above the editor and a footer with a context meter, activity, and
// model chips. Design: .plans/main/pi-statusbar/PRD.md.
// Currently implemented: the top row widget (dir, cost, elapsed time) and
// the footer (context meter, model chips).

import type {
  ExtensionAPI,
  ExtensionContext,
  SessionEntry,
  Theme,
  ThemeColor,
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

// Token count, `k`/`M`-scaled like the built-in footer: <1k plain, <10k
// `x.xk`, <1M `xk`, <10M `x.xM`, else `xM`.
function formatTokens(count: number): string {
  if (count < 1_000) return count.toString();
  if (count < 10_000) return `${(count / 1_000).toFixed(1)}k`;
  if (count < 1_000_000) return `${Math.round(count / 1_000)}k`;
  if (count < 10_000_000) return `${(count / 1_000_000).toFixed(1)}M`;
  return `${Math.round(count / 1_000_000)}M`;
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

// Join two groups on one line with the right group flush at `width`; when
// they don't fit, hard-clip like the validated prototype instead of moving
// the right group. An empty right group contributes nothing.
function joinSpread(width: number, left: string, right: string): string {
  if (right === "") return truncateToWidth(left, width, "");
  const pad = width - visibleWidth(left) - visibleWidth(right);
  return pad >= 1 ? left + " ".repeat(pad) + right : truncateToWidth(`${left} ${right}`, width, "");
}

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
  return [joinSpread(width, left, `${cost} ${time}`), rule];
}

// Context meter: 20 cells (shrinking below 85 columns is a later step); fill
// count = clamp(round(percent / 100 × cells)). Fill and percent share the
// used-% threshold color; track and window label stay dim.
const METER_CELLS = 20;
const METER_WARN_AT_PERCENT = 50;
const METER_ERROR_AT_PERCENT = 75;

// success below half, warning 50-74, error at 75+ (used-% semantics, not the
// built-in bar's 75/90 breakpoints).
function meterColor(percent: number): ThemeColor {
  if (percent >= METER_ERROR_AT_PERCENT) return "error";
  if (percent >= METER_WARN_AT_PERCENT) return "warning";
  return "success";
}

// `██████░░░░ 34.0%/1.0M` - bold percent in the threshold color, dim track
// and window label. Unknown usage renders the empty track with `--%`.
function renderMeter(percent: number | null, windowLabel: string, theme: Theme): string {
  if (percent === null) {
    return theme.fg("dim", `${"░".repeat(METER_CELLS)} --%${windowLabel}`);
  }
  const filled = Math.min(METER_CELLS, Math.max(0, Math.round((percent / 100) * METER_CELLS)));
  const color = meterColor(percent);
  return (
    theme.fg(color, "█".repeat(filled)) +
    theme.fg("dim", "░".repeat(METER_CELLS - filled)) +
    " " +
    theme.bold(theme.fg(color, `${percent.toFixed(1)}%`)) +
    theme.fg("dim", windowLabel)
  );
}

// Thinking level → theme token. `max` shares `thinkingXhigh` because
// `thinkingMax` is an optional token some themes lack.
type ThinkingLevel = NonNullable<ExtensionContext["thinkingLevel"]>;

const THINKING_TOKENS: Record<Exclude<ThinkingLevel, "off">, ThemeColor> = {
  minimal: "thinkingMinimal",
  low: "thinkingLow",
  medium: "thinkingMedium",
  high: "thinkingHigh",
  xhigh: "thinkingXhigh",
  max: "thinkingXhigh",
};

// Model chips: provider (dim), model id (accent), thinking level (level
// token). The thinking chip needs a reasoning model with a level set.
function renderChips(ctx: ExtensionContext, theme: Theme): string {
  const model = ctx.model;
  if (!model) return "";
  const chips = [theme.fg("dim", `${icons.provider} ${model.provider}`), theme.fg("accent", model.id)];
  const level = ctx.thinkingLevel;
  if (model.reasoning && level && level !== "off") {
    chips.push(theme.fg(THINKING_TOKENS[level], `${icons.think} ${level}`));
  }
  return chips.join(" ");
}

// Footer: a full-width rule, then the context meter left with model chips
// flush right. The activity segment (later step) slots between the meter and
// the spacer, so the right chips never move when it appears.
function renderFooter(width: number, theme: Theme): string[] {
  const rule = theme.fg("dim", "─".repeat(Math.max(0, width)));
  const ctx = latestCtx;
  if (!ctx) return [rule];

  const usage = ctx.getContextUsage();
  const meter = renderMeter(usage?.percent ?? null, usage ? `/${formatTokens(usage.contextWindow)}` : "", theme);
  return [rule, joinSpread(width, meter, renderChips(ctx, theme))];
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
        // Theme is pi's live proxy: fg() resolves the active theme at render
        // time, so a no-op invalidate() is correct.
        invalidate: () => {},
      }),
      { placement: "aboveEditor" },
    );
    ctx.ui.setFooter((_tui, theme, _footerData) => ({
      render: (width: number) => renderFooter(width, theme),
      // Same live-proxy reasoning as the widget's invalidate above.
      invalidate: () => {},
      dispose: () => {},
    }));
  });
}
