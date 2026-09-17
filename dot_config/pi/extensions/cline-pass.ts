/**
 * pi extension: ClinePass model discovery.
 *
 * Replaces the hand-maintained `cline-pass` provider in models.json with
 * live-discovered models from Cline's public API. Two endpoints are joined:
 *
 *   1. GET https://api.cline.bot/api/v1/ai/cline/recommended-models
 *        -> { clinePass: [{ id, name, description, tags }] }
 *      Selects WHICH models are ClinePass subscription models (ids prefixed
 *      with `cline-pass/`). Carries no pricing or context.
 *
 *   2. GET https://api.cline.bot/api/v1/ai/cline/models
 *        -> { data: [{ id, context_length, top_provider, pricing,
 *                      supported_parameters, architecture, ... }] }
 *      The full Cline catalog keyed by underlying provider id
 *      (`<provider>/<base>`, e.g. `z-ai/glm-5.3`). Supplies per-token
 *      pricing, context window, max output tokens, reasoning support, and
 *      input modalities.
 *
 * Each `cline-pass/<base>` id is matched to the catalog entry whose id ends
 * in `/<base>`. Pricing from the catalog is per-token and converted to
 * per-million-token rates. `input_cache_write` is never reported by the API,
 * so cacheWrite defaults to 0. When a cline-pass id has no catalog match, the
 * model is registered with safe defaults: 1M context, zero cost, reasoning,
 * text-only.
 *
 * Both endpoints are public (no key required); $CLINE_API_KEY is only used
 * for chat completions at request time.
 *
 * Graceful degradation:
 *   - recommended-models unreachable -> register nothing (we cannot know
 *     which models are ClinePass) and warn once per session.
 *   - /models unreachable but recommended-models ok -> register the
 *     cline-pass ids with default metadata (1M context, zero cost) and warn.
 *
 * Env:
 *   CLINE_API_KEY  Cline API key (resolved by pi via $CLINE_API_KEY).
 *
 * Commands:
 *   /cline-pass-refresh  Re-run discovery now. Applies immediately.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const PROVIDER_ID = "cline-pass";
const PROVIDER_NAME = "ClinePass";
const BASE_URL = "https://api.cline.bot/api/v1";
const RECOMMENDED_URL = "https://api.cline.bot/api/v1/ai/cline/recommended-models";
const CATALOG_URL = "https://api.cline.bot/api/v1/ai/cline/models";

const TIMEOUT_MS = 3_000;

const DEFAULT_CONTEXT_WINDOW = 1_000_000;
const DEFAULT_MAX_TOKENS = 16_384;
const MAX_TOKENS_CAP = 65_536;
const MAX_TOKENS_FLOOR = 4_096;
const ZERO_COST = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 } as const;

// OpenAI-compatible quirks for the Cline gateway, applied per model.
const COMPAT = {
  supportsDeveloperRole: false,
  supportsReasoningEffort: false,
  maxTokensField: "max_tokens",
} as const;

type Cost = {
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
};

interface ProviderModel {
  id: string;
  name: string;
  reasoning: boolean;
  input: ("text" | "image")[];
  cost: Cost;
  contextWindow: number;
  maxTokens: number;
}

interface RecommendedResponse {
  clinePass?: Array<{ id: string; name?: string; description?: string }>;
}

interface CatalogEntry {
  id: string;
  name?: string;
  context_length?: number | null;
  top_provider?: { context_length?: number | null; max_completion_tokens?: number | null } | null;
  supported_parameters?: string[] | null;
  pricing?: { prompt?: string | null; completion?: string | null; input_cache_read?: string | null } | null;
  architecture?: { input_modalities?: string[] | null } | null;
}

interface CatalogResponse {
  data?: CatalogEntry[];
}

type StartupStatus = "ok" | "recommended-down" | "catalog-down";

async function fetchJson<T>(url: string, extraSignal?: AbortSignal): Promise<T> {
  const signals = [AbortSignal.timeout(TIMEOUT_MS)];
  if (extraSignal) signals.push(extraSignal);
  const response = await fetch(url, { signal: AbortSignal.any(signals) });
  if (!response.ok) throw new Error(`HTTP ${response.status} from ${url}`);
  return (await response.json()) as T;
}

// Per-token price string -> per-million-token rate. Missing/invalid -> 0.
function perMillion(price: string | null | undefined): number {
  if (price === null || price === undefined || price === "") return 0;
  const value = Number.parseFloat(price);
  return Number.isFinite(value) ? value * 1_000_000 : 0;
}

function clampMaxTokens(value: number | null | undefined): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value <= 0) return DEFAULT_MAX_TOKENS;
  return Math.min(Math.max(Math.floor(value), MAX_TOKENS_FLOOR), MAX_TOKENS_CAP);
}

function supportsReasoning(params: string[] | null | undefined): boolean {
  return Boolean(params?.some((p) => p === "include_reasoning" || p === "reasoning"));
}

function inputsFrom(modalities: string[] | null | undefined): ("text" | "image")[] {
  return modalities?.includes("image") ? ["text", "image"] : ["text"];
}

// Indexes the catalog by the base name (the segment after the first `/`),
// so `cline-pass/glm-5.3` resolves to `z-ai/glm-5.3`. First match wins.
function indexCatalog(entries: CatalogEntry[]): Map<string, CatalogEntry> {
  const index = new Map<string, CatalogEntry>();
  for (const entry of entries) {
    if (!entry.id) continue;
    const base = entry.id.slice(entry.id.indexOf("/") + 1);
    if (base && !index.has(base)) index.set(base, entry);
  }
  return index;
}

function modelFromCatalog(id: string, entry: CatalogEntry): ProviderModel {
  const contextWindow =
    entry.top_provider?.context_length ?? entry.context_length ?? DEFAULT_CONTEXT_WINDOW;
  return {
    id,
    name: entry.name ?? id.replace(/^cline-pass\//, ""),
    reasoning: supportsReasoning(entry.supported_parameters),
    input: inputsFrom(entry.architecture?.input_modalities),
    cost: {
      input: perMillion(entry.pricing?.prompt),
      output: perMillion(entry.pricing?.completion),
      cacheRead: perMillion(entry.pricing?.input_cache_read),
      cacheWrite: 0, // The API never reports input_cache_write.
    },
    contextWindow,
    maxTokens: clampMaxTokens(entry.top_provider?.max_completion_tokens),
  };
}

function defaultModel(id: string, name?: string, description?: string): ProviderModel {
  const text = (description ?? "").toLowerCase();
  const multimodal =
    text.includes("multimodal") || text.includes("vision") || text.includes("image");
  return {
    id,
    name: name ?? id.replace(/^cline-pass\//, ""),
    reasoning: true,
    input: multimodal ? ["text", "image"] : ["text"],
    cost: { ...ZERO_COST },
    contextWindow: DEFAULT_CONTEXT_WINDOW,
    maxTokens: DEFAULT_MAX_TOKENS,
  };
}

interface Discovery {
  models: ProviderModel[];
  status: StartupStatus;
}

async function discoverModels(signal?: AbortSignal): Promise<Discovery> {
  const recommended = await fetchJson<RecommendedResponse>(RECOMMENDED_URL, signal);
  const ids = (recommended.clinePass ?? [])
    .map((entry) => entry.id)
    .filter((id): id is string => typeof id === "string" && id.startsWith("cline-pass/"));
  if (ids.length === 0) throw new Error("ClinePass catalog returned no models");

  let catalog: Map<string, CatalogEntry>;
  try {
    const payload = await fetchJson<CatalogResponse>(CATALOG_URL, signal);
    catalog = indexCatalog(payload.data ?? []);
  } catch {
    // recommended-models ok, /models down: register ids with default metadata.
    return { models: ids.map((id) => defaultModel(id)), status: "catalog-down" };
  }

  const models = ids.map((id) => {
    const base = id.replace(/^cline-pass\//, "");
    const entry = catalog.get(base);
    return entry ? modelFromCatalog(id, entry) : defaultModel(id);
  });
  return { models, status: "ok" };
}

export default async function (pi: ExtensionAPI) {
  const register = (models: ProviderModel[]) => {
    pi.registerProvider(PROVIDER_ID, {
      name: PROVIDER_NAME,
      baseUrl: BASE_URL,
      apiKey: "$CLINE_API_KEY",
      api: "openai-completions",
      authHeader: true,
      models: models.map((m) => ({ ...m, compat: { ...COMPAT } })),
      refreshModels: async ({ signal }: { signal: AbortSignal }) => {
        try {
          return (await discoverModels(signal)).models.map((m) => ({ ...m, compat: { ...COMPAT } }));
        } catch {
          return []; // recommended-models went away: cannot determine the ClinePass set.
        }
      },
    });
  };

  let status: StartupStatus = "ok";
  let registeredCount = 0;
  try {
    const discovery = await discoverModels();
    register(discovery.models);
    status = discovery.status;
    registeredCount = discovery.models.length;
  } catch {
    status = "recommended-down";
  }

  pi.on("session_start", async (event, ctx) => {
    if (event.reason !== "startup" && event.reason !== "reload") return;
    if (status === "ok") return;
    const message =
      status === "recommended-down"
        ? "ClinePass recommended-models endpoint unreachable: no ClinePass models registered"
        : `ClinePass model catalog unreachable: registered ${registeredCount} models with default metadata`;
    if (ctx.hasUI) ctx.ui.notify(message, "warning");
    else console.warn(`[cline-pass] ${message}`);
  });

  pi.registerCommand("cline-pass-refresh", {
    description: "Re-discover ClinePass models from the Cline API",
    handler: async (_args, ctx) => {
      const notify = (message: string, level: "info" | "warning") => {
        if (ctx.hasUI) ctx.ui.notify(message, level);
        else console.warn(`[cline-pass] ${message}`);
      };
      try {
        const discovery = await discoverModels();
        register(discovery.models);
        status = discovery.status;
        registeredCount = discovery.models.length;
        const suffix = status === "ok" ? "" : " (catalog metadata unavailable, using defaults)";
        notify(`ClinePass: ${discovery.models.length} models registered${suffix}`, status === "ok" ? "info" : "warning");
      } catch {
        status = "recommended-down";
        notify("ClinePass recommended-models endpoint unreachable: no models registered", "warning");
      }
    },
  });
}
