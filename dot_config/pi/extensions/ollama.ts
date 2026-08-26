/**
 * pi extension: Ollama model discovery (local + cloud).
 *
 * While the Ollama daemon is reachable, this replaces the static "ollama"
 * provider from models.json with live-discovered models:
 *   - local: GET {host}/api/tags (capabilities -> reasoning/vision, context_length)
 *   - cloud: https://ollama.com/v1/models catalog, each entry validated and
 *     enriched through the daemon's POST /api/show as "<id>:cloud"
 *
 * Graceful degradation:
 *   - Daemon unreachable  -> register nothing (the static models.json list
 *     stays as fallback) and show a single warning notification per session.
 *   - Cloud catalog down  -> local models only, single warning notification.
 *
 * Env:
 *   OLLAMA_HOST      Daemon base URL (default http://127.0.0.1:11434).
 *   PI_OLLAMA_CLOUD  "on"/"1"/"true"/"yes" enables cloud discovery (default off).
 *
 * Commands:
 *   /ollama-refresh  Re-run discovery now, e.g. after `ollama pull` or after
 *                    starting the daemon. Applies immediately, no /reload needed.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const PROVIDER_ID = "ollama";
const DEFAULT_HOST = "http://127.0.0.1:11434";
const CLOUD_CATALOG_URL = "https://ollama.com/v1/models";
const CLOUD_MODEL_SUFFIX = ":cloud";

const PROBE_TIMEOUT_MS = 1_500;
const TAGS_TIMEOUT_MS = 2_000;
const CATALOG_TIMEOUT_MS = 3_000;
const SHOW_TIMEOUT_MS = 4_000;
const SHOW_CONCURRENCY = 6;

// Fallbacks for models whose metadata lacks a context length (e.g. MLX).
// Cap local windows well below the true model limit: ollama's /v1 endpoint
// sends no bytes until the whole prompt is processed, and pi aborts after
// its httpIdleTimeoutMs (default 5 min). At ~350 tok/s prefill, windows
// above ~65k tokens cannot finish prefill in time, so pi would time out on
// every request once a session grows near the window.
const DEFAULT_CONTEXT_WINDOW = 262_144;
const MAX_LOCAL_CONTEXT_WINDOW = 131_072;
const DEFAULT_MAX_TOKENS = 16_384;
const ZERO_COST = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 } as const;

interface ModelConfig {
  id: string;
  name: string;
  reasoning: boolean;
  input: ("text" | "image")[];
  cost: { input: number; output: number; cacheRead: number; cacheWrite: number };
  contextWindow: number;
  maxTokens: number;
}

interface OllamaTagsResponse {
  models?: Array<{
    name: string;
    capabilities?: string[];
    details?: { context_length?: number };
  }>;
}

interface OllamaShowResponse {
  capabilities?: string[];
  model_info?: Record<string, unknown>;
  error?: string;
}

interface CloudCatalogResponse {
  data?: Array<{ id?: string }>;
}

interface Discovery {
  local: ModelConfig[];
  cloud: ModelConfig[];
  cloudError: boolean;
}

type StartupStatus = "ok" | "daemon-down" | "cloud-down";

function hostFromEnv(): string {
  const raw = (process.env.OLLAMA_HOST ?? "").trim();
  if (!raw) return DEFAULT_HOST;
  const withScheme = /^https?:\/\//.test(raw) ? raw : `http://${raw}`;
  return withScheme.replace(/\/+$/, "");
}

function cloudDiscoveryEnabled(): boolean {
  const raw = (process.env.PI_OLLAMA_CLOUD ?? "").trim().toLowerCase();
  return ["on", "1", "true", "yes"].includes(raw);
}

async function fetchJson<T>(
  url: string,
  timeoutMs: number,
  init?: RequestInit,
  extraSignal?: AbortSignal,
): Promise<T> {
  const signals = [AbortSignal.timeout(timeoutMs)];
  if (extraSignal) signals.push(extraSignal);
  const response = await fetch(url, { ...init, signal: AbortSignal.any(signals) });
  if (!response.ok) throw new Error(`HTTP ${response.status} from ${url}`);
  return (await response.json()) as T;
}

async function probeDaemon(host: string): Promise<boolean> {
  try {
    await fetchJson(`${host}/api/version`, PROBE_TIMEOUT_MS);
    return true;
  } catch {
    return false;
  }
}

function inputFromCapabilities(capabilities: string[]): ("text" | "image")[] {
  return capabilities.includes("vision") ? ["text", "image"] : ["text"];
}

function contextLengthFrom(modelInfo: Record<string, unknown> | undefined): number | undefined {
  if (!modelInfo) return undefined;
  for (const [key, value] of Object.entries(modelInfo)) {
    if (key.endsWith(".context_length") && typeof value === "number" && value > 0) return value;
  }
  return undefined;
}

async function discoverLocalModels(host: string, signal?: AbortSignal): Promise<ModelConfig[]> {
  const payload = await fetchJson<OllamaTagsResponse>(
    `${host}/api/tags`,
    TAGS_TIMEOUT_MS,
    undefined,
    signal,
  );
  const models = (payload.models ?? []).filter((model) =>
    (model.capabilities ?? ["completion"]).includes("completion"),
  );

  // MLX models report no context_length in /api/tags; fetch the precise
  // value from /api/show (fast, local) instead of guessing.
  const enriched = await Promise.all(
    models.map(async (model) => {
      let contextWindow = model.details?.context_length ?? undefined;
      if (contextWindow === undefined) {
        contextWindow = await contextLengthFromShow(host, model.name, signal);
      }
      return {
        id: model.name,
        name: model.name,
        reasoning: (model.capabilities ?? []).includes("thinking"),
        input: inputFromCapabilities(model.capabilities ?? []),
        cost: { ...ZERO_COST },
        contextWindow: Math.min(contextWindow ?? DEFAULT_CONTEXT_WINDOW, MAX_LOCAL_CONTEXT_WINDOW),
        maxTokens: DEFAULT_MAX_TOKENS,
      };
    }),
  );
  return enriched;
}

// Returns the model's true context length via /api/show, or undefined when
// the daemon does not report one (or is too slow to answer).
async function contextLengthFromShow(
  host: string,
  modelName: string,
  signal?: AbortSignal,
): Promise<number | undefined> {
  try {
    const payload = await fetchJson<OllamaShowResponse>(
      `${host}/api/show`,
      SHOW_TIMEOUT_MS,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name: modelName }),
      },
      signal,
    );
    return contextLengthFrom(payload.model_info);
  } catch {
    return undefined;
  }
}

async function fetchCloudCatalog(signal?: AbortSignal): Promise<string[]> {
  const payload = await fetchJson<CloudCatalogResponse>(
    CLOUD_CATALOG_URL,
    CATALOG_TIMEOUT_MS,
    undefined,
    signal,
  );
  return (payload.data ?? [])
    .map((entry) => entry.id)
    .filter((id): id is string => typeof id === "string" && id.length > 0);
}

// Validates a catalog entry against the signed-in daemon and enriches it with
// capabilities and context length. Returns null when the model is unusable.
async function resolveCloudModel(
  host: string,
  catalogId: string,
  signal?: AbortSignal,
): Promise<ModelConfig | null> {
  const id = `${catalogId}${CLOUD_MODEL_SUFFIX}`;
  try {
    const payload = await fetchJson<OllamaShowResponse>(
      `${host}/api/show`,
      SHOW_TIMEOUT_MS,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name: id }),
      },
      signal,
    );
    if (payload.error) return null;
    const capabilities = payload.capabilities ?? [];
    return {
      id,
      name: `${catalogId} (cloud)`,
      reasoning: capabilities.includes("thinking"),
      input: inputFromCapabilities(capabilities),
      cost: { ...ZERO_COST },
      contextWindow: contextLengthFrom(payload.model_info) ?? DEFAULT_CONTEXT_WINDOW,
      maxTokens: DEFAULT_MAX_TOKENS,
    };
  } catch {
    return null;
  }
}

async function discoverCloudModels(host: string, signal?: AbortSignal): Promise<ModelConfig[]> {
  const catalog = await fetchCloudCatalog(signal);
  const resolved: ModelConfig[] = [];
  for (let i = 0; i < catalog.length; i += SHOW_CONCURRENCY) {
    const chunk = catalog.slice(i, i + SHOW_CONCURRENCY);
    const models = await Promise.all(chunk.map((id) => resolveCloudModel(host, id, signal)));
    for (const model of models) {
      if (model) resolved.push(model);
    }
  }
  return resolved;
}

async function discoverModels(host: string, signal?: AbortSignal): Promise<Discovery> {
  const local = await discoverLocalModels(host, signal);
  let cloud: ModelConfig[] = [];
  let cloudError = false;
  if (cloudDiscoveryEnabled()) {
    try {
      cloud = await discoverCloudModels(host, signal);
    } catch {
      cloudError = true;
    }
  }
  const localIds = new Set(local.map((model) => model.id));
  return { local, cloud: cloud.filter((model) => !localIds.has(model.id)), cloudError };
}

export default async function (pi: ExtensionAPI) {
  const host = hostFromEnv();

  const register = (models: ModelConfig[]) => {
    pi.registerProvider(PROVIDER_ID, {
      name: "Ollama",
      baseUrl: `${host}/v1`,
      apiKey: "ollama", // Placeholder: the daemon ignores it, pi requires one.
      api: "openai-completions",
      models,
      refreshModels: async ({ signal }: { signal: AbortSignal }) => {
        try {
          const { local, cloud } = await discoverModels(host, signal);
          return [...local, ...cloud];
        } catch {
          return []; // Daemon went away: no ollama models are currently usable.
        }
      },
    });
  };

  let status: StartupStatus = "ok";
  if (await probeDaemon(host)) {
    try {
      const { local, cloud, cloudError } = await discoverModels(host);
      register([...local, ...cloud]);
      if (cloudError) status = "cloud-down";
    } catch {
      status = "daemon-down";
    }
  } else {
    status = "daemon-down";
  }

  pi.on("session_start", async (event, ctx) => {
    if (event.reason !== "startup" && event.reason !== "reload") return;
    if (status === "ok") return;
    const message =
      status === "daemon-down"
        ? `Ollama not reachable at ${host}: local and cloud models unavailable`
        : "Ollama cloud catalog unreachable: registered local models only";
    if (ctx.hasUI) {
      ctx.ui.notify(message, "warning");
    } else {
      console.warn(`[ollama] ${message}`);
    }
  });

  pi.registerCommand("ollama-refresh", {
    description: "Re-discover Ollama local and cloud models",
    handler: async (_args, ctx) => {
      const notify = (message: string, level: "info" | "warning") => {
        if (ctx.hasUI) {
          ctx.ui.notify(message, level);
        } else {
          console.warn(`[ollama] ${message}`);
        }
      };

      if (!(await probeDaemon(host))) {
        status = "daemon-down";
        notify(`Ollama not reachable at ${host}: local and cloud models unavailable`, "warning");
        return;
      }

      const { local, cloud, cloudError } = await discoverModels(host);
      register([...local, ...cloud]);
      status = cloudError ? "cloud-down" : "ok";

      const summary = `Ollama: ${local.length} local + ${cloud.length} cloud models registered`;
      notify(cloudError ? `${summary} (cloud catalog unreachable)` : summary, cloudError ? "warning" : "info");
    },
  });
}
