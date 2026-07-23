/**
 * pi extension: skill collision priority.
 *
 * pi resolves skill-name collisions by "first found", and it scans PROJECT skill
 * directories before USER ones — so a repo skill always shadows your global skill
 * of the same name. This extension re-resolves those collisions so USER skills win
 * by default, and exposes an env var to control the order.
 *
 * Env:  PI_SKILL_PRIORITY = comma-separated priority of buckets.
 *       Buckets: user, project, temporary
 *       Default (unset): "user,project"        -> your global skill wins over the repo's
 *       PI_SKILL_PRIORITY=project              -> restore pi's native (repo-wins) behavior
 *       PI_SKILL_PRIORITY=project,user         -> explicit repo-first ordering
 *
 * Scope: collisions among the standard skill directories are re-resolved
 *   user:    $PI_CODING_AGENT_DIR/skills and ~/.agents/skills
 *   project: <cwd>/.pi/skills and <cwd>-and-ancestors/.agents/skills
 * Both model auto-invocation (system prompt) and explicit /skill:name honor it,
 * reusing pi's own per-directory discovery (loadSkillsFromDir) and formatters, so
 * it stays in sync with pi rather than reimplementing skill parsing.
 *
 * Limitation: skills supplied via settings/packages/CLI that collide with a
 * standard-dir skill are overridden by the standard-dir winner. Collisions that do
 * not involve a standard directory fall through to pi's native resolution.
 */

import {
  CONFIG_DIR_NAME,
  formatSkillsForPrompt,
  getAgentDir,
  loadSkillsFromDir,
  stripFrontmatter,
  type ExtensionAPI,
  type Skill,
} from "@earendil-works/pi-coding-agent";
import { existsSync, readFileSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";

const ENV_PRIORITY = "PI_SKILL_PRIORITY";
const DEFAULT_PRIORITY = "user,project";
const KNOWN_BUCKETS = ["user", "project", "temporary"] as const;
const SKILL_PREFIX = "/skill:";

// Matches the exact "<available_skills>" section formatSkillsForPrompt emits.
const SKILLS_BLOCK_RE =
  /\n\nThe following skills provide specialized instructions for specific tasks\.[\s\S]*?<\/available_skills>/;

// pi's native discovery order (project before user before temporary).
const PI_NATIVE_RANK: Record<Bucket, number> = { project: 0, user: 1, temporary: 2 };

type Bucket = (typeof KNOWN_BUCKETS)[number];

interface Candidate {
  skill: Skill;
  bucket: Bucket;
}

interface Index {
  /** Policy winner per name, for standard skill directories. */
  winners: Map<string, Skill>;
  /** Collision names whose policy winner differs from pi's native winner. */
  changed: Set<string>;
}

let cacheKey: string | null = null;
let cache: Index | null = null;

export default function (pi: ExtensionAPI): void {
  // Rebuild the index for every session (cwd or priority may have changed).
  pi.on("session_start", async (event, ctx) => {
    cache = null;
    cacheKey = null;
    if (event.reason !== "startup") return;
    const index = getIndex(ctx.cwd);
    if (ctx.hasUI && index.changed.size > 0) {
      ctx.ui.notify(
        `skill-priority (${parsePriority().join(" > ")}): ${index.changed.size} collision(s) re-resolved`,
        "info",
      );
    }
  });

  // Rewrite the <available_skills> block so model auto-invocation uses our winners.
  pi.on("before_agent_start", async (event, ctx) => {
    const index = getIndex(ctx.cwd);
    const piSkills = (event.systemPromptOptions?.skills ?? []) as Skill[];

    const merged = mergeWithPi(index, piSkills);
    const visibleMerged = merged.filter((s) => !s.disableModelInvocation);
    const visiblePi = piSkills.filter((s) => !s.disableModelInvocation);
    if (sameSet(visibleMerged, visiblePi)) return; // nothing changed vs pi's resolution

    const rewritten = replaceBlock(event.systemPrompt, formatSkillsForPrompt(visibleMerged));
    if (rewritten === event.systemPrompt) return;
    return { systemPrompt: rewritten };
  });

  // Resolve explicit /skill:name with our winner (only where it actually differs).
  pi.on("input", async (event, ctx) => {
    const text = event.text;
    if (typeof text !== "string" || !text.startsWith(SKILL_PREFIX)) return { action: "continue" };

    const { name, args } = parseSkillCommand(text);
    const index = getIndex(ctx.cwd);
    if (!index.changed.has(name)) return { action: "continue" }; // let pi handle the rest

    const winner = index.winners.get(name);
    if (!winner) return { action: "continue" };

    let content: string;
    try {
      content = readFileSync(winner.filePath, "utf-8");
    } catch {
      return { action: "continue" };
    }

    const body = stripFrontmatter(content).trim();
    const block =
      `<skill name="${winner.name}" location="${winner.filePath}">\n` +
      `References are relative to ${winner.baseDir}.\n\n${body}\n</skill>`;
    return { action: "transform", text: args ? `${block}\n\n${args}` : block };
  });
}

// ---------------------------------------------------------------------------
// Index construction — reuses pi's own per-directory discovery (no cross-dedup)
// ---------------------------------------------------------------------------

function getIndex(cwd: string): Index {
  const key = `${cwd}::${parsePriority().join(",")}`;
  if (cache && cacheKey === key) return cache;
  cache = buildIndex(cwd);
  cacheKey = key;
  return cache;
}

function buildIndex(cwd: string): Index {
  const dirs: Array<{ dir: string; bucket: Bucket }> = [
    { dir: join(getAgentDir(), "skills"), bucket: "user" },
    { dir: join(homedir(), ".agents", "skills"), bucket: "user" },
    { dir: join(cwd, CONFIG_DIR_NAME, "skills"), bucket: "project" },
    ...ancestorAgentsSkillDirs(cwd).map((dir) => ({ dir, bucket: "project" as Bucket })),
  ];

  const candidates = new Map<string, Candidate[]>();
  for (const { dir, bucket } of dirs) {
    if (!existsSync(dir) || !statSync(dir).isDirectory()) continue;
    for (const skill of loadDir(dir, bucket)) {
      const list = candidates.get(skill.name) ?? [];
      list.push({ skill, bucket });
      candidates.set(skill.name, list);
    }
  }

  const priority = parsePriority();
  const winners = new Map<string, Skill>();
  const changed = new Set<string>();
  for (const [name, list] of candidates) {
    const mine = pickByRank(list, rankFor(priority));
    winners.set(name, mine.skill);
    if (list.length > 1) {
      const native = pickByRank(list, (b) => PI_NATIVE_RANK[b]);
      if (mine.skill.filePath !== native.skill.filePath) changed.add(name);
    }
  }
  return { winners, changed };
}

function loadDir(dir: string, bucket: Bucket): Skill[] {
  try {
    return loadSkillsFromDir({ dir, source: bucket }).skills ?? [];
  } catch {
    return [];
  }
}

function pickByRank(list: Candidate[], rank: (b: Bucket) => number): Candidate {
  return list.slice().sort((a, b) => rank(a.bucket) - rank(b.bucket))[0];
}

function rankFor(priority: Bucket[]): (b: Bucket) => number {
  return (b) => {
    const i = priority.indexOf(b);
    return i === -1 ? Number.MAX_SAFE_INTEGER : i;
  };
}

// Mirrors pi's project .agents/skills discovery: cwd up through the git root.
function ancestorAgentsSkillDirs(cwd: string): string[] {
  const out: string[] = [];
  const userAgentSkills = resolve(homedir(), ".agents", "skills");
  let cur = resolve(cwd);
  for (;;) {
    const candidate = join(cur, ".agents", "skills");
    if (resolve(candidate) !== userAgentSkills && isDir(candidate)) out.push(candidate);
    if (existsSync(join(cur, ".git"))) break;
    const parent = dirname(cur);
    if (parent === cur) break;
    cur = parent;
  }
  return out;
}

// ---------------------------------------------------------------------------
// Merge / comparison / prompt rewrite
// ---------------------------------------------------------------------------

function mergeWithPi(index: Index, piSkills: Skill[]): Skill[] {
  const merged: Skill[] = [];
  const seen = new Set<string>();
  for (const [name, skill] of index.winners) {
    merged.push(skill);
    seen.add(name);
  }
  for (const skill of piSkills) {
    if (!seen.has(skill.name)) {
      merged.push(skill);
      seen.add(skill.name);
    }
  }
  return merged;
}

function sameSet(a: Skill[], b: Skill[]): boolean {
  return signature(a) === signature(b);
}

function signature(list: Skill[]): string {
  return list.map((s) => `${s.name}\u0000${s.filePath}`).sort().join("\n");
}

function replaceBlock(prompt: string, block: string): string {
  return SKILLS_BLOCK_RE.test(prompt) ? prompt.replace(SKILLS_BLOCK_RE, block) : prompt;
}

function parseSkillCommand(text: string): { name: string; args: string } {
  const space = text.indexOf(" ");
  if (space === -1) return { name: text.slice(SKILL_PREFIX.length), args: "" };
  return { name: text.slice(SKILL_PREFIX.length, space), args: text.slice(space + 1).trim() };
}

function parsePriority(): Bucket[] {
  const raw = (process.env[ENV_PRIORITY] ?? DEFAULT_PRIORITY).trim();
  const known = raw
    .split(",")
    .map((t) => t.trim().toLowerCase())
    .filter((t): t is Bucket => (KNOWN_BUCKETS as readonly string[]).includes(t));
  return known.length > 0 ? known : (DEFAULT_PRIORITY.split(",") as Bucket[]);
}

function isDir(path: string): boolean {
  return existsSync(path) && statSync(path).isDirectory();
}
