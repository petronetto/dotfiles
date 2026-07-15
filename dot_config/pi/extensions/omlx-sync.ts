import fs from "node:fs/promises";
import path from "node:path";
import os from "node:os";

export default function (pi: any) {
  // Triggers automatically every time you start a new Pi session
  pi.on("session_start", async (_event: any, ctx: any) => {
    const host = process.env.OMLX_HOST || "http://localhost";
    const port = process.env.OMLX_PORT || "1986";
    const apiKey = process.env.OMLX_API_KEY || "sk-omlx-Lj35qZrm1kU7ffkKRpprEP5W";

    const baseUrl = `${host}:${port}/v1`;

    try {
      const res = await fetch(`${baseUrl}/models`, {
        headers: { "Authorization": `Bearer ${apiKey}` }
      });

      if (!res.ok) return;

      const data = await res.json();
      const models = data.data.map((m: any) => ({
        id: m.id,
        input: ["text"]
      }));

      const modelsJsonPath = path.join(os.homedir(), ".pi", "agent", "models.json");

      let modelsConfig: any = { providers: {} };
      try {
        const existing = await fs.readFile(modelsJsonPath, "utf-8");
        modelsConfig = JSON.parse(existing);
      } catch (e) {
        // File doesn't exist or is invalid, start fresh
      }

      modelsConfig.providers = modelsConfig.providers || {};
      modelsConfig.providers.omlx = {
        baseUrl: baseUrl,
        api: "openai-completions",
        apiKey: apiKey,
        compat: {
          // Optimizes local LLM compatibility by bypassing features they often lack
          supportsDeveloperRole: false,
          supportsReasoningEffort: false
        },
        models: models
      };

      await fs.writeFile(modelsJsonPath, JSON.stringify(modelsConfig, null, 2));

      // Let's you know the sync worked without being intrusive
      ctx.ui.notify("oMLX models synced successfully", "info");

    } catch (err) {
      // Fails silently so it doesn't break your Pi startup if oMLX is turned off
    }
  });
}