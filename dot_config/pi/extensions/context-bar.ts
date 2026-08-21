// Context Bar - pi extension that replaces the built-in footer so the stats
// line can lead with a visual context-usage bar.
//
// Forked from pi 0.84.2 dist/modes/interactive/components/footer.js
// (FooterComponent.render): extension APIs cannot reorder the built-in
// footer, so ctx.ui.setFooter() installs this re-implementation instead.
// Footer internals are not a stable API - re-diff that file after pi
// upgrades.

import { getAgentDir } from "@earendil-works/pi-coding-agent";
import type {
  ExtensionAPI,
  ExtensionContext,
  ReadonlyFooterDataProvider,
  SessionEntry,
  Theme,
} from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth, type Component } from "@earendil-works/pi-tui";
import { readFileSync, statSync } from "node:fs";
import { isAbsolute, join, relative, resolve, sep } from "node:path";

// Token-format thresholds and minimum padding mirror the built-in footer.
const TOKENS_PER_K = 1_000;
const TOKENS_10K = 10_000;
const TOKENS_PER_M = 1_000_000;
const TOKENS_10M = 10_000_000;
const MIN_STATS_PADDING = 2;
// Context-percent color thresholds, matching the built-in footer (70/90).
const WARN_AT_PERCENT = 70;
const CRITICAL_AT_PERCENT = 90;

// Pull-based rendering: the TUI calls render() on every repaint, and this
// context (live getters) is refreshed on every session_start.
let latestCtx: ExtensionContext | undefined;

function sanitizeStatusText(text: string): string {
  return text
    .replace(/[\r\n\t]/g, " ")
    .replace(/ +/g, " ")
    .trim();
}

function formatTokens(count: number): string {
  if (count < TOKENS_PER_K) return count.toString();
  if (count < TOKENS_10K) return `${(count / TOKENS_PER_K).toFixed(1)}k`;
  if (count < TOKENS_PER_M) return `${Math.round(count / TOKENS_PER_K)}k`;
  if (count < TOKENS_10M) return `${(count / TOKENS_PER_M).toFixed(1)}M`;
  return `${Math.round(count / TOKENS_PER_M)}M`;
}

function formatCwdForFooter(cwd: string, home: string | undefined): string {
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

interface TokenUsage {
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
  cost: { total: number };
}

interface UsageTotals {
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
  cost: number;
}

function addUsageToTotals(totals: UsageTotals, usage: TokenUsage): void {
  totals.input += usage.input;
  totals.output += usage.output;
  totals.cacheRead += usage.cacheRead;
  totals.cacheWrite += usage.cacheWrite;
  totals.cost += usage.cost.total;
}

function collectSessionUsage(
  entries: SessionEntry[],
): { totals: UsageTotals; cacheHitRate: number | undefined } {
  const totals: UsageTotals = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0 };
  let cacheHitRate: number | undefined;
  for (const entry of entries) {
    if (entry.type === "message" && entry.message.role === "assistant") {
      const usage = entry.message.usage;
      addUsageToTotals(totals, usage);
      const promptTokens = usage.input + usage.cacheRead + usage.cacheWrite;
      cacheHitRate = promptTokens > 0 ? (usage.cacheRead / promptTokens) * 100 : undefined;
    } else if (entry.type === "message" && entry.message.role === "toolResult" && entry.message.usage) {
      addUsageToTotals(totals, entry.message.usage);
    } else if ((entry.type === "branch_summary" || entry.type === "compaction") && entry.usage) {
      addUsageToTotals(totals, entry.usage);
    }
  }
  return { totals, cacheHitRate };
}

// Kimi Coding is subscription-backed despite using API-key authentication.
function isUsingSubscription(ctx: ExtensionContext): boolean {
  const model = ctx.model;
  if (!model) return false;
  if (model.provider === "kimi-coding") return true;
  return (
    ctx.modelRegistry.isUsingOAuth(model) &&
    ctx.modelRegistry.getProvider(model.provider)?.auth.oauth?.isSubscription === true
  );
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function deepMergeSettings(
  base: Record<string, unknown>,
  overrides: Record<string, unknown>,
): Record<string, unknown> {
  const result = { ...base };
  for (const [key, value] of Object.entries(overrides)) {
    if (value === undefined) continue;
    const baseValue = result[key];
    result[key] = isPlainObject(baseValue) && isPlainObject(value) ? deepMergeSettings(baseValue, value) : value;
  }
  return result;
}

interface CachedSettingsFile {
  mtimeMs: number;
  settings: Record<string, unknown>;
}

const settingsFileCache = new Map<string, CachedSettingsFile>();

function readSettingsFile(path: string): Record<string, unknown> {
  let mtimeMs: number;
  try {
    mtimeMs = statSync(path).mtimeMs;
  } catch {
    settingsFileCache.delete(path);
    return {};
  }
  const cached = settingsFileCache.get(path);
  if (cached && cached.mtimeMs === mtimeMs) return cached.settings;
  let settings: Record<string, unknown> = {};
  try {
    const parsed: unknown = JSON.parse(readFileSync(path, "utf8"));
    if (isPlainObject(parsed)) settings = parsed;
  } catch {
    settings = {};
  }
  settingsFileCache.set(path, { mtimeMs, settings });
  return settings;
}

// Mirrors pi's SettingsManager resolution: global settings (agent dir) deep
// merged with project .pi/settings.json, project taking precedence. Project
// settings are ignored when the project is untrusted, like upstream.
function readCompactionEnabled(cwd: string, projectTrusted: boolean): boolean {
  const globalSettings = readSettingsFile(join(getAgentDir(), "settings.json"));
  const projectSettings = projectTrusted ? readSettingsFile(join(cwd, ".pi", "settings.json")) : {};
  const merged = deepMergeSettings(globalSettings, projectSettings);
  const compaction = merged.compaction;
  if (!isPlainObject(compaction)) return true;
  return Boolean(compaction.enabled ?? true);
}

class ContextBarFooter implements Component {
  constructor(
    private readonly theme: Theme,
    private readonly footerData: ReadonlyFooterDataProvider,
    private readonly unsubscribeBranchChange: () => void,
  ) {}

  dispose(): void {
    this.unsubscribeBranchChange();
  }

  // No-op, matching the built-in footer: git branch is cached by the provider.
  invalidate(): void {}

  render(width: number): string[] {
    const ctx = latestCtx;
    if (!ctx) return [];
    const { theme, footerData } = this;
    const model = ctx.model;

    const { totals: usageTotals, cacheHitRate } = collectSessionUsage(ctx.sessionManager.getEntries());

    // After compaction, tokens are unknown until the next LLM response.
    const contextUsage = ctx.getContextUsage();
    const contextWindow = contextUsage?.contextWindow ?? model?.contextWindow ?? 0;
    const contextPercentValue = contextUsage?.percent ?? 0;
    const contextPercent = contextUsage?.percent !== null ? contextPercentValue.toFixed(1) : "?";

    const cwd = ctx.sessionManager.getCwd();
    let pwd = formatCwdForFooter(cwd, process.env.HOME || process.env.USERPROFILE);
    const branch = footerData.getGitBranch();
    if (branch) {
      pwd = `${pwd} (${branch})`;
    }
    const sessionName = ctx.sessionManager.getSessionName();
    if (sessionName) {
      pwd = `${pwd} • ${sessionName}`;
    }

    const statsParts: string[] = [];
    if (usageTotals.input) statsParts.push(`↑${formatTokens(usageTotals.input)}`);
    if (usageTotals.output) statsParts.push(`↓${formatTokens(usageTotals.output)}`);
    if (usageTotals.cacheRead) statsParts.push(`R${formatTokens(usageTotals.cacheRead)}`);
    if (usageTotals.cacheWrite) statsParts.push(`W${formatTokens(usageTotals.cacheWrite)}`);
    if ((usageTotals.cacheRead > 0 || usageTotals.cacheWrite > 0) && cacheHitRate !== undefined) {
      statsParts.push(`CH${cacheHitRate.toFixed(1)}%`);
    }
    const subscription = isUsingSubscription(ctx);
    if (usageTotals.cost || subscription) {
      statsParts.push(`$${usageTotals.cost.toFixed(3)}${subscription ? " (sub)" : ""}`);
    }

    const autoIndicator = readCompactionEnabled(cwd, ctx.isProjectTrusted()) ? " (auto)" : "";
    const contextPercentDisplay =
      contextPercent === "?"
        ? `?/${formatTokens(contextWindow)}${autoIndicator}`
        : `${contextPercent}%/${formatTokens(contextWindow)}${autoIndicator}`;
    // The context segment leads the stats line as its own color run (dim
    // below the warning threshold): its trailing reset would clear a dim
    // wrapper around the following stats, so those dim as a separate run.
    let contextSegment: string;
    if (contextPercentValue > CRITICAL_AT_PERCENT) {
      contextSegment = theme.fg("error", contextPercentDisplay);
    } else if (contextPercentValue > WARN_AT_PERCENT) {
      contextSegment = theme.fg("warning", contextPercentDisplay);
    } else {
      contextSegment = theme.fg("dim", contextPercentDisplay);
    }

    if (process.env.PI_EXPERIMENTAL === "1") {
      statsParts.push(`${theme.fg("dim", "•")} ${theme.bold(theme.fg("warning", "xp"))}`);
    }

    const statsRest = statsParts.join(" ");
    let statsLeft = statsRest ? `${contextSegment} ${theme.fg("dim", statsRest)}` : contextSegment;
    const modelName = model?.id || "no-model";
    let statsLeftWidth = visibleWidth(statsLeft);
    if (statsLeftWidth > width) {
      statsLeft = truncateToWidth(statsLeft, width, "...");
      statsLeftWidth = visibleWidth(statsLeft);
    }

    let rightSideWithoutProvider = modelName;
    if (model?.reasoning) {
      const thinkingLevel = ctx.thinkingLevel || "off";
      rightSideWithoutProvider =
        thinkingLevel === "off" ? `${modelName} • thinking off` : `${modelName} • ${thinkingLevel}`;
    }

    // Prepend the provider in parentheses if there are multiple providers and there's enough room.
    let rightSide = rightSideWithoutProvider;
    if (footerData.getAvailableProviderCount() > 1 && model) {
      rightSide = `(${model.provider}) ${rightSideWithoutProvider}`;
      if (statsLeftWidth + MIN_STATS_PADDING + visibleWidth(rightSide) > width) {
        rightSide = rightSideWithoutProvider;
      }
    }

    const rightSideWidth = visibleWidth(rightSide);
    const totalNeeded = statsLeftWidth + MIN_STATS_PADDING + rightSideWidth;
    let statsLine: string;
    if (totalNeeded <= width) {
      const padding = " ".repeat(width - statsLeftWidth - rightSideWidth);
      statsLine = statsLeft + padding + rightSide;
    } else {
      const availableForRight = width - statsLeftWidth - MIN_STATS_PADDING;
      if (availableForRight > 0) {
        const truncatedRight = truncateToWidth(rightSide, availableForRight, "");
        const truncatedRightWidth = visibleWidth(truncatedRight);
        const padding = " ".repeat(Math.max(0, width - statsLeftWidth - truncatedRightWidth));
        statsLine = statsLeft + padding + truncatedRight;
      } else {
        statsLine = statsLeft;
      }
    }

    // statsLeft is fully styled already (context segment color run + dim
    // token stats); only the padding + right side still needs dimming.
    const remainder = statsLine.slice(statsLeft.length);
    const dimRemainder = theme.fg("dim", remainder);
    const pwdLine = truncateToWidth(theme.fg("dim", pwd), width, theme.fg("dim", "..."));
    const lines = [pwdLine, statsLeft + dimRemainder];

    const extensionStatuses = footerData.getExtensionStatuses();
    if (extensionStatuses.size > 0) {
      const statusLine = Array.from(extensionStatuses.entries())
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([, text]) => sanitizeStatusText(text))
        .join(" ");
      lines.push(truncateToWidth(statusLine, width, theme.fg("dim", "...")));
    }

    return lines;
  }
}

export default function contextBar(pi: ExtensionAPI): void {
  pi.on("session_start", (_event, ctx) => {
    latestCtx = ctx;
    if (!ctx.hasUI) return;
    ctx.ui.setFooter((tui, theme, footerData) => {
      const unsubscribe = footerData.onBranchChange(() => tui.requestRender());
      return new ContextBarFooter(theme, footerData, unsubscribe);
    });
  });
}
