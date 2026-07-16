// Registers oMLX as a local model provider so its models appear in pi's
// model selection and are available via `pi --list-models`.

export default async function (pi: any) {
  const host = process.env.OMLX_HOST || "http://localhost";
  const port = process.env.OMLX_PORT || "8000";
  const apiKey = process.env.OMLX_API_KEY;

  const baseUrl = `${host}:${port}/v1`;

  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 3_000);

    const res = await fetch(`${baseUrl}/models`, {
      headers: { "Authorization": `Bearer ${apiKey}` },
      signal: controller.signal,
    });
    clearTimeout(timeout);

    if (!res.ok) return;

    const data = await res.json();
    const models = data.data.map((m: any) => ({
      id: m.id,
      name: m.id,
      input: ["text"],
      reasoning: false,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
      contextWindow: m.max_model_len ?? 32768,
      maxTokens: 4096,
    }));

    pi.registerProvider("omlx", {
      baseUrl,
      apiKey,
      api: "openai-completions",
      models,
    });
  } catch (error) {
    console.error("Failed to sync oMLX models");
    console.error(error);
  }
}
