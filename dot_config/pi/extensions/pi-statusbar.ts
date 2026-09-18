// pi-statusbar - structured status area for pi: a location/git/cost/time
// widget above the editor and a footer with a context meter, activity, and
// model chips. Design: .plans/main/pi-statusbar/PRD.md.
// Currently implemented: the top row widget (dir, git, cost, elapsed time)
// and the footer (context meter, activity, model chips, extension statuses)
// with width-based collapse (compact meter, chip drops, truncation), plus
// the `/statusbar` command toggling all of it off/on for the session.

import type {
  ExtensionAPI,
  ExtensionContext,
  ReadonlyFooterDataProvider,
  SessionEntry,
  Theme,
  ThemeColor,
} from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth, type TUI } from "@earendil-works/pi-tui";
import { statSync, watch, type FSWatcher } from "node:fs";
import { isAbsolute, join, relative, resolve, sep } from "node:path";

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
// Pull-based rendering: renderers read only this cached state, refreshed off
// the render path on session_start, branch changes, and debounced .git
// watches.
let latestCtx: ExtensionContext | undefined;
let latestTui: TUI | undefined;
// Stable handle on the extension API: `exec` for the git spawn lives here,
// not on the per-session context.
let piApi: ExtensionAPI | undefined;
let sessionStart = 0;
// Session-scoped /statusbar toggle (Goal 10): true = our surfaces installed.
// Never persisted anywhere; a fresh session_start always re-arms it.
let statusbarActive = true;

// Last parsed `git status --porcelain -b`; null = no repo, detached HEAD, or
// not yet fetched. Written only by refreshGitSnapshot().
let gitSnapshot: GitSnapshot | null = null;

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

// ── Git snapshot ──
// Goal 8: a cached parse of `git status --porcelain -b`, refreshed off the
// render path (session_start, branch changes, debounced .git watches);
// renderers only ever read `gitSnapshot`.

interface GitSnapshot {
  branch: string;
  staged: number;
  modified: number;
  ahead: number;
  dirty: boolean;
}

const GIT_WATCH_DEBOUNCE_MS = 250;
// Caps a hung spawn so the single-flight flag below cannot wedge shut.
const GIT_EXEC_TIMEOUT_MS = 5_000;

let gitRefreshInFlight = false;
let gitWatchers: FSWatcher[] = [];
let gitWatchTimer: ReturnType<typeof setTimeout> | undefined;

// Pure parse of `git status --porcelain -b` v1 output. null = not a repo
// (empty/malformed output) or detached HEAD. An unborn branch
// (`## No commits yet on <branch>`) still yields a branch. Ignored entries
// (`!!`) are not changes; untracked (`??`) count as modified; conflict
// codes (ADU combos) count via their columns. `behind` is parsed as part of
// the header but intentionally not kept: only `↑N` is displayed.
function parseGitStatus(output: string): GitSnapshot | null {
  const lines = output.split("\n");
  const header = (lines[0] ?? "").trim();
  if (header === "## HEAD (no branch)") return null; // detached
  const headerMatch = /^## (?:No commits yet on )?(\S+)/.exec(header);
  if (!headerMatch) return null;
  // `...upstream` follows the branch in `## <branch>...<upstream>`; branch
  // names cannot contain `..`.
  const branch = headerMatch[1].split("...", 1)[0];

  let staged = 0;
  let modified = 0;
  for (const line of lines.slice(1)) {
    // Status rows are exactly `XY <path>`; anything else is skipped.
    const x = line[0];
    const y = line[1];
    if (!x || !y || line[2] !== " ") continue;
    if (x === "!" && y === "!") continue; // ignored file
    if (x !== " " && x !== "?") staged += 1;
    if (y !== " " && y !== "?") modified += 1;
    else if (x === "?") modified += 1; // untracked counts as modified
  }

  const ahead = /\[ahead (\d+)/.exec(header);
  return {
    branch,
    staged,
    modified,
    ahead: ahead ? Number(ahead[1]) : 0,
    dirty: staged > 0 || modified > 0,
  };
}

// Failure rule: a failed or empty status keeps the previous snapshot
// (transient git errors must not blink the chip away); only session_start
// resets to null, so leaving a repo clears on the next session.
// Single-flight: concurrent triggers drop re-entry instead of stacking
// spawns; a later trigger re-runs.
async function refreshGitSnapshot(): Promise<void> {
  if (gitRefreshInFlight) return;
  const ctx = latestCtx;
  const api = piApi;
  if (!ctx || !api) return;
  gitRefreshInFlight = true;
  try {
    const result = await api.exec("git", ["status", "--porcelain", "-b"], {
      cwd: ctx.cwd,
      timeout: GIT_EXEC_TIMEOUT_MS,
    });
    if (result.code === 0 && result.stdout !== "") {
      gitSnapshot = parseGitStatus(result.stdout);
      latestTui?.requestRender(); // repaint so fresh counts show without input
    }
  } catch {
    // exec() resolves failures into the result; this only keeps the
    // fire-and-forget call from ever rejecting.
  } finally {
    gitRefreshInFlight = false;
  }
}

// One shared timer for both watched files: the trailing debounce coalesces
// the burst a branch switch causes (HEAD rewrite, then an index update).
function scheduleGitRefresh(): void {
  if (gitWatchTimer !== undefined) clearTimeout(gitWatchTimer);
  gitWatchTimer = setTimeout(() => {
    gitWatchTimer = undefined;
    void refreshGitSnapshot();
  }, GIT_WATCH_DEBOUNCE_MS);
}

// Watch .git/HEAD and .git/index so edits made outside pi refresh the
// counts. Plain repos only: a linked worktree (.git as a file) or a missing
// repo skips the watcher - branch switches there still refresh via
// onBranchChange and session events.
function startGitWatchers(): void {
  stopGitWatchers(); // re-arm on every session_start: the cwd may have moved
  const ctx = latestCtx;
  if (!ctx) return;
  const gitDir = resolve(ctx.cwd, ".git");
  try {
    if (!statSync(gitDir).isDirectory()) return;
  } catch {
    return; // no .git here
  }
  for (const name of ["HEAD", "index"]) {
    try {
      const watcher = watch(join(gitDir, name), () => scheduleGitRefresh());
      // Without an error handler a watcher error would crash the process.
      watcher.on("error", () => watcher.close()); // e.g. the file vanished
      gitWatchers.push(watcher);
    } catch {
      // A missing file (a fresh repo has no index yet) just means no watch.
    }
  }
}

// Idempotent teardown, safe to call from both components' dispose() and
// every session_start.
function stopGitWatchers(): void {
  for (const watcher of gitWatchers) watcher.close();
  gitWatchers = [];
  if (gitWatchTimer !== undefined) {
    clearTimeout(gitWatchTimer);
    gitWatchTimer = undefined;
  }
}

// ── Activity ──
// Goal 9: while a run is active the footer's activity segment is the single
// working indicator; pi's built-in working row is hidden at install (D9) and
// only restored by the /statusbar toggle (step 006).

// Braille frames from the validated prototype, in advance order.
const SPINNER_FRAMES = [
  "\u280B",
  "\u2819",
  "\u2839",
  "\u2838",
  "\u283C",
  "\u2834",
  "\u2826",
  "\u2827",
  "\u2807",
  "\u280F",
];
const SPINNER_INTERVAL_MS = 120;

type ActivityPhase = "idle" | "thinking" | "streaming";

let activityPhase: ActivityPhase = "idle";
let spinFrame = 0;
let spinTimer: ReturnType<typeof setInterval> | undefined;

function startSpinner(): void {
  if (spinTimer !== undefined) return;
  spinTimer = setInterval(() => {
    spinFrame = (spinFrame + 1) % SPINNER_FRAMES.length;
    latestTui?.requestRender();
  }, SPINNER_INTERVAL_MS);
}

// Idempotent: agent_end and agent_settled can both land idle, and dispose
// must be safe on an already-stopped timer.
function stopSpinner(): void {
  if (spinTimer === undefined) return;
  clearInterval(spinTimer);
  spinTimer = undefined;
}

// Repaints on transition so the segment appears/disappears on the event
// instead of waiting for the next tick.
function setActivityPhase(phase: ActivityPhase): void {
  if (activityPhase === phase) return;
  activityPhase = phase;
  if (phase === "idle") stopSpinner();
  else startSpinner();
  latestTui?.requestRender();
}

// ── Rendering ──
// Pure string builders over cached state only; never throw on missing data.
// No separator rules: pi's editor already draws border lines above and
// below the prompt, so ours would double them.

// Join two groups on one line with the right group flush at `width`; when
// they don't fit, hard-clip like the validated prototype instead of moving
// the right group. An empty right group contributes nothing.
function joinSpread(width: number, left: string, right: string): string {
  if (right === "") return truncateToWidth(left, width, "");
  const pad = width - visibleWidth(left) - visibleWidth(right);
  return pad >= 1 ? left + " ".repeat(pad) + right : truncateToWidth(`${left} ${right}`, width, "");
}

// Git chip: branch icon + branch name in the success token (the
// prototype's green chip), a state dot (success when clean, warning when
// dirty - the prototype's identity dot), then dim change counts and ahead
// marker. Absent outside a repo / detached HEAD.
function renderGitChip(theme: Theme): string {
  const snapshot = gitSnapshot;
  if (!snapshot) return "";
  const dot = theme.fg(snapshot.dirty ? "warning" : "success", icons.dot);
  const parts = [theme.fg("success", `${icons.branch} ${snapshot.branch}`), dot];
  if (snapshot.staged > 0) parts.push(theme.fg("dim", `+${snapshot.staged}`));
  if (snapshot.modified > 0) parts.push(theme.fg("dim", `~${snapshot.modified}`));
  if (snapshot.ahead > 0) parts.push(theme.fg("dim", `${icons.up}${snapshot.ahead}`));
  return parts.join(" ");
}

// Top row: folder icon + ~-shortened cwd and the git chip left, session
// cost and elapsed time right.
function renderTopRow(width: number, theme: Theme): string[] {
  const ctx = latestCtx;
  if (!ctx) return [];

  const cwd = shortenCwd(ctx.sessionManager.getCwd(), process.env.HOME || process.env.USERPROFILE);
  const dir = theme.fg("dim", `${icons.folder} ${cwd}`);
  const gitChip = renderGitChip(theme);
  const left = gitChip === "" ? dir : `${dir} ${gitChip}`;
  const cost = theme.fg("dim", `${icons.cost} ${formatCost(collectSessionCost(ctx.sessionManager.getBranch()))}`);
  const time = theme.fg("dim", `${icons.clock} ${formatElapsed(Math.max(0, Date.now() - sessionStart))}`);
  return [joinSpread(width, left, `${cost} ${time}`)];
}

// Context meter: 20 cells at ≥ 85 columns, 10 below (D10); fill count =
// clamp(round(percent / 100 × cells)). Fill and percent share the used-%
// threshold color; track and window label stay dim.
const METER_CELLS = 20;
const METER_CELLS_COMPACT = 10;
const COMPACT_BELOW_COLS = 85;
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
// and window label. Unknown usage renders the empty track with `--%`. The
// cell count follows the footer width: compact below 85 columns (D10).
function renderMeter(width: number, percent: number | null, windowLabel: string, theme: Theme): string {
  const cells = width >= COMPACT_BELOW_COLS ? METER_CELLS : METER_CELLS_COMPACT;
  if (percent === null) {
    return theme.fg("dim", `${"░".repeat(cells)} --%${windowLabel}`);
  }
  const filled = Math.min(cells, Math.max(0, Math.round((percent / 100) * cells)));
  const color = meterColor(percent);
  return (
    theme.fg(color, "█".repeat(filled)) +
    theme.fg("dim", "░".repeat(cells - filled)) +
    " " +
    theme.bold(theme.fg(color, `${percent.toFixed(1)}%`)) +
    theme.fg("dim", windowLabel)
  );
}

// Activity segment: spinner frame + phase label in the accent token (the
// prototype's purple intent, mapped to pi's closest semantic token).
// Absent while idle; composed before the spacer in renderFooter (D11), so
// appearing or disappearing never moves the right chips.
function renderActivity(theme: Theme): string {
  if (activityPhase === "idle") return "";
  const label = activityPhase === "thinking" ? "thinking" : "streaming";
  return theme.fg("accent", `${SPINNER_FRAMES[spinFrame % SPINNER_FRAMES.length]} ${label}`);
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

// Footer chips in display order; `thinking` is "" when hidden (no reasoning
// model or level off). Fields, not a joined string, so the width collapse
// can drop chips without parsing styled text.
interface ModelChips {
  provider: string;
  model: string;
  thinking: string;
}

// Model chips: provider (dim), model id (accent), thinking level (level
// token). The thinking chip needs a reasoning model with a level set.
function renderChips(ctx: ExtensionContext, theme: Theme): ModelChips | null {
  const model = ctx.model;
  if (!model) return null;
  const level = ctx.thinkingLevel;
  return {
    provider: theme.fg("dim", `${icons.provider} ${model.provider}`),
    model: theme.fg("accent", model.id),
    thinking:
      model.reasoning && level && level !== "off"
        ? theme.fg(THINKING_TOKENS[level], `${icons.think} ${level}`)
        : "",
  };
}

// Width collapse for the footer row (Goal 11): the right side sheds chips
// before anything truncates - provider first, then thinking; the model chip
// persists. The first variant that fits wins; only when even the model-only
// row overflows does joinSpread hard-clip it.
function fitFooterRow(width: number, left: string, chips: ModelChips | null): string {
  if (!chips) return joinSpread(width, left, "");
  const variants = [
    [chips.provider, chips.model, chips.thinking],
    [chips.model, chips.thinking],
    [chips.model],
  ];
  for (const variant of variants) {
    const right = variant.filter((chip) => chip !== "").join(" ");
    // Strictly < width: joinSpread also needs room for the separator space.
    if (visibleWidth(left) + visibleWidth(right) < width) {
      return joinSpread(width, left, right);
    }
  }
  return joinSpread(width, left, chips.model);
}

// Status texts are single-line footer material: control whitespace becomes
// spaces, runs collapse, edges trim (context-bar statuses-line precedent).
function sanitizeStatusText(text: string): string {
  return text
    .replace(/[\r\n\t]/g, " ")
    .replace(/ +/g, " ")
    .trim();
}

// Extension statuses (Goal 4): other extensions' setStatus texts as a
// conditional last footer line (D2) so they never vanish. Sorted by
// extension key, dimmed as secondary signals. Empty after sanitizing (no
// statuses, or whitespace-only ones) renders nothing, never a blank row.
function renderStatuses(width: number, theme: Theme, footerData: ReadonlyFooterDataProvider): string {
  const line = Array.from(footerData.getExtensionStatuses().entries())
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([, text]) => sanitizeStatusText(text))
    .filter(Boolean)
    .join(" ");
  return line === "" ? "" : truncateToWidth(theme.fg("dim", line), width, theme.fg("dim", "..."));
}

// Footer: the context meter and activity segment left with model chips
// flush right, then the statuses line when another extension has set one.
// The activity segment composes before the spacer, so the right chips
// never move when it appears or disappears.
function renderFooter(width: number, theme: Theme, footerData: ReadonlyFooterDataProvider): string[] {
  const ctx = latestCtx;
  if (!ctx) return [];

  const usage = ctx.getContextUsage();
  const meter = renderMeter(width, usage?.percent ?? null, usage ? `/${formatTokens(usage.contextWindow)}` : "", theme);
  const activity = renderActivity(theme);
  const left = activity === "" ? meter : `${meter} ${activity}`;
  const lines = [fitFooterRow(width, left, renderChips(ctx, theme))];
  const statuses = renderStatuses(width, theme, footerData);
  if (statuses !== "") lines.push(statuses);
  return lines;
}

// ── Install / teardown ──
// Goal 10: one install path shared by session_start and the /statusbar
// toggle; teardown restores every surface pi had before. Both take whichever
// context is at hand (session or command - both expose `ui`). pi repaints on
// every set* call, so the swap appears without an explicit requestRender.
function installStatusbar(ctx: ExtensionContext): void {
  statusbarActive = true; // a fresh session always starts with the statusbar on
  ctx.ui.setWidget(
    "pi-statusbar",
    (tui, theme) => {
      latestTui = tui;
      return {
        render: (width: number) => renderTopRow(width, theme),
        // Theme is pi's live proxy: fg() resolves the active theme at render
        // time, so a no-op invalidate() is correct.
        invalidate: () => {},
        dispose: () => {
          stopGitWatchers();
          stopSpinner(); // the timer must not outlive the widget
        },
      };
    },
    { placement: "aboveEditor" },
  );
  ctx.ui.setFooter((_tui, theme, footerData) => {
    // Branch switches are detected by pi's own HEAD watcher; refresh our
    // snapshot against the new branch (the repaint happens when the
    // refresh lands).
    const unsubscribeBranchChange = footerData.onBranchChange(() => {
      void refreshGitSnapshot();
    });
    return {
      render: (width: number) => renderFooter(width, theme, footerData),
      // Same live-proxy reasoning as the widget's invalidate above.
      invalidate: () => {},
      dispose: () => {
        unsubscribeBranchChange();
        stopGitWatchers();
      },
    };
  });
  // The footer's activity segment is the single working indicator (D9);
  // teardown restores the default for /statusbar off.
  ctx.ui.setWorkingIndicator({ frames: [] });
  startGitWatchers();
  void refreshGitSnapshot();
}

// Removes all three surfaces and restores pi's built-ins. The module-level
// cleanup runs explicitly (idempotent) instead of relying on the widget
// dispose that setWidget(key, undefined) happens to trigger.
function teardownStatusbar(ctx: ExtensionContext): void {
  statusbarActive = false;
  ctx.ui.setWidget("pi-statusbar", undefined);
  ctx.ui.setFooter(undefined);
  ctx.ui.setWorkingIndicator(); // no argument restores the built-in indicator
  setActivityPhase("idle"); // also stops the spinner timer
  stopGitWatchers();
}

export default function piStatusbar(pi: ExtensionAPI): void {
  piApi = pi;
  // Run-phase tracking is state-only, so it registers outside the hasUI
  // guard; in print/RPC modes latestTui is unset and the repaints no-op.
  pi.on("agent_start", () => setActivityPhase("thinking"));
  pi.on("message_update", (event) => {
    const delta = event.assistantMessageEvent?.type;
    if (delta === "thinking_delta") setActivityPhase("thinking");
    else if (delta === "text_delta") setActivityPhase("streaming");
    // Other delta kinds (tool calls, usage…) leave the phase unchanged.
  });
  // agent_end goes idle even though pi may auto-retry or queue a continuation
  // right after: the next agent_start re-arms the spinner, and agent_settled
  // forces idle for queued continuations that never fire another agent_end.
  pi.on("agent_end", () => setActivityPhase("idle"));
  pi.on("agent_settled", () => setActivityPhase("idle"));
  // Chips read cached ctx state; these selections change it mid-session.
  pi.on("model_select", (_event, ctx) => {
    latestCtx = ctx;
    latestTui?.requestRender();
  });
  pi.on("thinking_level_select", (_event, ctx) => {
    latestCtx = ctx;
    latestTui?.requestRender();
  });
  pi.on("session_start", (_event, ctx) => {
    latestCtx = ctx;
    sessionStart = Date.now();
    gitSnapshot = null; // install's refresh re-fills it; failures keep it null
    stopGitWatchers(); // the previous session's watchers must not survive
    setActivityPhase("idle"); // the previous session's phase must not survive either
    if (!ctx.hasUI) return;
    installStatusbar(ctx);
  });
  // /statusbar (Goal 10): session-scoped toggle. Off tears our surfaces down
  // so the built-in footer and working indicator return; on reinstalls them.
  // State lives only in this session - session_start re-arms it, nothing is
  // persisted to settings.
  pi.registerCommand("statusbar", {
    description: "Toggle the status bar",
    handler: async (_args, cmdCtx) => {
      if (!cmdCtx.hasUI) return; // no surfaces to swap in print/RPC modes
      if (statusbarActive) teardownStatusbar(cmdCtx);
      else installStatusbar(cmdCtx);
    },
  });
}
