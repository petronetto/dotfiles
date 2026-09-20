// pi-statusbar - structured status area for pi: a location/git/time widget
// above the editor and a footer with a context meter, session token
// totals, and model chips. Design: .plans/main/pi-statusbar/PRD.md.
// Currently implemented: the top row widget (dir, git, last-response time)
// and the footer (context meter, token totals, model chips, extension
// statuses) with width-based collapse (compact meter, chip drops,
// truncation), plus the `/statusbar` command toggling all of it off/on for
// the session. pi's native working indicator is left untouched.
// Styling: ADR-003 terminal palette chips — every background and foreground
// is an ANSI palette index (SGR 38/48;5;N, N ∈ 0-15), so the terminal maps
// the colors: changing the Ghostty theme recolors the whole bar. No hexes.

import type {
  ExtensionAPI,
  ExtensionContext,
  ReadonlyFooterDataProvider,
  SessionEntry,
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
  up: "\u2191",
  down: "\u2193",
} as const;

const ASCII_ICONS = {
  folder: "~",
  branch: "git:",
  provider: "api:",
  think: "th:",
  clock: "@",
  up: "^",
  down: "v",
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
// Last-response timer: while a run is active the time chip ticks with the
// live elapsed; agent_end freezes it into lastResponseMs. null = no response
// yet in this session.
let activeRunStart: number | null = null;
let lastResponseMs: number | null = null;
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

// `42s` under a minute, `12m05s` under an hour, `1h02m` at or over.
function formatDuration(ms: number): string {
  const totalSeconds = Math.floor(ms / 1000);
  if (totalSeconds < 60) return `${totalSeconds}s`;
  const minutes = Math.floor(totalSeconds / 60);
  if (minutes < 60) return `${minutes}m${String(totalSeconds % 60).padStart(2, "0")}s`;
  return `${Math.floor(minutes / 60)}h${String(minutes % 60).padStart(2, "0")}m`;
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

// Session token totals over the active branch - assistant replies,
// toolResult messages carrying usage, and branch summary/compaction entries
// carrying usage. Follows the built-in footer's convention: ↑ input, ↓ output;
// cache read/write stay out to avoid inflating cached sessions.
interface SessionTokens {
  input: number;
  output: number;
}

function collectSessionTokens(entries: SessionEntry[]): SessionTokens {
  let input = 0;
  let output = 0;
  for (const entry of entries) {
    if (entry.type === "message" && entry.message.role === "assistant") {
      input += entry.message.usage.input;
      output += entry.message.usage.output;
    } else if (entry.type === "message" && entry.message.role === "toolResult" && entry.message.usage) {
      input += entry.message.usage.input;
      output += entry.message.usage.output;
    } else if ((entry.type === "branch_summary" || entry.type === "compaction") && entry.usage) {
      input += entry.usage.input;
      output += entry.usage.output;
    }
  }
  return { input, output };
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

// ── Palette chips (ADR-003) ──
// Every segment renders as a solid chip whose colors are ANSI palette
// indices (0-15), the way the terminal defines them. Ghostty maps these to
// the active theme, so switching the terminal theme recolors the bar with
// zero changes here; light themes keep working because the palette roles
// (red/green/blue/gray…) invert with the theme. No fixed hexes anywhere.

// Palette indices by role. 0 is the theme's opposite-of-background color,
// which is why it doubles as chip text on colored backgrounds.
const PAL = {
  black: 0, // chip text on colored backgrounds
  red: 1, // meter error fill
  green: 2, // meter ok fill, clean git chip
  yellow: 3, // meter warn fill, dirty git chip
  blue: 4, // model chip
  magenta: 5, // free role (no current chip uses it)
  cyan: 6, // thinking chip
  gray: 7, // secondary text on the default background
  panel: 8, // neutral chip background (the theme's "bright black" gray)
} as const;

// Segment colors: one named variable per chip role, so every look knob
// lives here. Values are PAL roles, per ADR-003.
const COLORS = {
  chipText: PAL.black, // fg on colored chip backgrounds
  neutralBg: PAL.panel, // neutral chip background (dir, time, provider…)
  meterTrack: PAL.panel, // meter track and frame
  meterOk: PAL.green,
  meterWarn: PAL.yellow,
  meterError: PAL.red,
  gitClean: PAL.green,
  gitDirty: PAL.yellow,
  model: PAL.blue,
  thinking: PAL.cyan,
  secondaryFg: PAL.gray, // secondary text on the default background
} as const;

// Palette-indexed foreground; `\x1b[39m` resets to the terminal's default
// fg, which is what the segments are separated by.
function pal(n: number, text: string): string {
  return `\x1b[38;5;${n}m${text}\x1b[39m`;
}

// Solid chip: palette background with padded content, closed with a
// background reset so the separating space renders on the default
// background. `inner` must carry its own foreground.
function chip(bg: number, inner: string): string {
  return `\x1b[48;5;${bg}m ${inner} \x1b[49m`;
}

// Neutral chip: the theme's gray (palette 8) as background and the
// terminal's default fg as text — both ends of that pair invert with the
// theme, so it stays readable in light and dark themes alike.
function neutralChip(text: string): string {
  return chip(COLORS.neutralBg, text);
}

// Identity chip: colored background (palette 1-6) with palette-black text,
// the standard colored-badge contrast: the theme defines 0 as the color
// that opposes the colored backgrounds it ships.
function colorChip(bg: number, text: string): string {
  return chip(bg, pal(COLORS.chipText, text));
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

// Git chip: branch icon + name + dim counts. The chip background carries
// the state (green when clean, yellow when dirty) instead of the old state
// dot, which cannot contrast inside a solid chip. Absent outside a repo /
// detached HEAD.
function renderGitChip(): string {
  const snapshot = gitSnapshot;
  if (!snapshot) return "";
  const parts = [`${icons.branch} ${snapshot.branch}`];
  if (snapshot.staged > 0) parts.push(`+${snapshot.staged}`);
  if (snapshot.modified > 0) parts.push(`~${snapshot.modified}`);
  if (snapshot.ahead > 0) parts.push(`${icons.up}${snapshot.ahead}`);
  return colorChip(snapshot.dirty ? COLORS.gitDirty : COLORS.gitClean, parts.join(" "));
}

// Top row: folder icon + current directory name (not the whole path) and
// the git chip left, last-response time right; all neutrals as panel-gray
// chips with default-fg text.
function renderTopRow(width: number): string[] {
  const ctx = latestCtx;
  if (!ctx) return [];

  const cwd = shortenCwd(ctx.sessionManager.getCwd(), process.env.HOME || process.env.USERPROFILE);
  const dirName = cwd.split(sep).pop() || cwd;
  const dir = neutralChip(`${icons.folder} ${dirName}`);
  const gitChip = renderGitChip();
  const left = gitChip === "" ? dir : `${dir} ${gitChip}`;
  // Live elapsed while a run is active, the frozen last-response time after
  // it ends; `--` before the first response of the session.
  const elapsed = activeRunStart !== null ? Date.now() - activeRunStart : lastResponseMs;
  const time = neutralChip(`${icons.clock} ${elapsed === null ? "--" : formatDuration(elapsed)}`);
  return [joinSpread(width, left, time)];
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
// built-in bar's 75/90 breakpoints). Palette index, not a theme token.
function meterColor(percent: number): number {
  if (percent >= METER_ERROR_AT_PERCENT) return COLORS.meterError;
  if (percent >= METER_WARN_AT_PERCENT) return COLORS.meterWarn;
  return COLORS.meterOk;
}

// Meter chip: one framed block of colored fill cells on a panel-gray track,
// then a bold percent in the threshold color and a gray window label, all
// outside the chip. Unknown usage renders the empty track with `--%`. The
// cell count follows the footer width: compact below 85 columns (D10).
function renderMeter(width: number, percent: number | null, windowLabel: string): string {
  const cells = width >= COMPACT_BELOW_COLS ? METER_CELLS : METER_CELLS_COMPACT;
  // One continuous background run: panel pad, colored fill cells, panel
  // track, panel pad — the trailing reset only lands after the whole frame.
  const bar = (color: number, filled: number) =>
    `\x1b[48;5;${COLORS.meterTrack}m \x1b[48;5;${color}m${" ".repeat(filled)}` +
    `\x1b[48;5;${COLORS.meterTrack}m${" ".repeat(cells - filled)} \x1b[49m`;
  if (percent === null) {
    return `${bar(COLORS.meterTrack, 0)} ${pal(COLORS.secondaryFg, `--%${windowLabel}`)}`;
  }
  const filled = Math.min(cells, Math.max(0, Math.round((percent / 100) * cells)));
  const color = meterColor(percent);
  return (
    `${bar(color, filled)} ` +
    `\x1b[1m${pal(color, `${percent.toFixed(1)}%`)}\x1b[22m` +
    pal(COLORS.secondaryFg, windowLabel)
  );
}

// Footer chips in display order; `thinking` is "" when hidden (no reasoning
// model or level off). Fields, not a joined string, so the width collapse
// can drop chips without parsing styled text.
interface ModelChips {
  provider: string;
  model: string;
  thinking: string;
}

// Model chips (the prototype's ordering): provider in a neutral chip,
// model id in a blue chip, thinking level in a cyan chip. The thinking chip
// needs a reasoning model with a level set.
function renderChips(ctx: ExtensionContext): ModelChips | null {
  const model = ctx.model;
  if (!model) return null;
  const level = ctx.thinkingLevel;
  return {
    provider: neutralChip(`${icons.provider} ${model.provider}`),
    model: colorChip(COLORS.model, model.id),
    thinking: model.reasoning && level && level !== "off" ? colorChip(COLORS.thinking, `${icons.think} ${level}`) : "",
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
// extension key, dimmed as a secondary signal in a neutral block. Empty
// after sanitizing (no statuses, or whitespace-only ones) renders nothing,
// never a blank row.
function renderStatuses(width: number, footerData: ReadonlyFooterDataProvider): string {
  const line = Array.from(footerData.getExtensionStatuses().entries())
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([, text]) => sanitizeStatusText(text))
    .filter(Boolean)
    .join(" ");
  if (line === "") return "";
  return truncateToWidth(neutralChip(line), width, "...");
}

// Footer: the context meter with session token totals left, model chips
// flush right, then the statuses line when another extension has set one.
function renderFooter(width: number, footerData: ReadonlyFooterDataProvider): string[] {
  const ctx = latestCtx;
  if (!ctx) return [];

  const usage = ctx.getContextUsage();
  const meter = renderMeter(width, usage?.percent ?? null, usage ? `/${formatTokens(usage.contextWindow)}` : "");
  const tokens = collectSessionTokens(ctx.sessionManager.getBranch());
  const tokensChip = neutralChip(`${icons.up}${formatTokens(tokens.input)} ${icons.down}${formatTokens(tokens.output)}`);
  const lines = [fitFooterRow(width, `${meter} ${tokensChip}`, renderChips(ctx))];
  const statuses = renderStatuses(width, footerData);
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
    (tui, _theme) => {
      latestTui = tui;
      return {
        render: (width: number) => renderTopRow(width),
        // invalidate() is a no-op: nothing depends on the pi theme anymore —
        // colors are palette indices the terminal resolves.
        invalidate: () => {},
        dispose: () => {
          stopGitWatchers();
        },
      };
    },
    { placement: "aboveEditor" },
  );
  ctx.ui.setFooter((_tui, _theme, footerData) => {
    // Branch switches are detected by pi's own HEAD watcher; refresh our
    // snapshot against the new branch (the repaint happens when the
    // refresh lands).
    const unsubscribeBranchChange = footerData.onBranchChange(() => {
      void refreshGitSnapshot();
    });
    return {
      render: (width: number) => renderFooter(width, footerData),
      // Same palette-index reasoning as the widget's invalidate above.
      invalidate: () => {},
      dispose: () => {
        unsubscribeBranchChange();
        stopGitWatchers();
      },
    };
  });
  // pi's native working indicator is left untouched (D9 reversed, Q14).
  startGitWatchers();
  void refreshGitSnapshot();
}

// Removes both surfaces and restores pi's built-in footer. The module-level
// cleanup runs explicitly (idempotent) instead of relying on the widget
// dispose that setWidget(key, undefined) happens to trigger.
function teardownStatusbar(ctx: ExtensionContext): void {
  statusbarActive = false;
  ctx.ui.setWidget("pi-statusbar", undefined);
  ctx.ui.setFooter(undefined);
  stopGitWatchers();
}

export default function piStatusbar(pi: ExtensionAPI): void {
  piApi = pi;
  // Run-phase tracking is state-only, so it registers outside the hasUI
  // guard; in print/RPC modes latestTui is unset and the repaints no-op.
  pi.on("agent_start", () => {
    activeRunStart = Date.now();
    latestTui?.requestRender();
  });
  // Freeze the last-response timer; a retried or queued continuation starts
  // a fresh run on its next agent_start.
  pi.on("agent_end", () => {
    if (activeRunStart !== null) lastResponseMs = Date.now() - activeRunStart;
    activeRunStart = null;
    latestTui?.requestRender();
  });
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
    activeRunStart = null;
    lastResponseMs = null;
    gitSnapshot = null; // install's refresh re-fills it; failures keep it null
    stopGitWatchers(); // the previous session's watchers must not survive
    if (!ctx.hasUI) return;
    installStatusbar(ctx);
  });
  // /statusbar (Goal 10): session-scoped toggle. Off tears our surfaces down
  // so the built-in footer returns; on, it reinstalls them.
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
