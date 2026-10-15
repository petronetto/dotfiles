// /clear - start a fresh session but keep the current model and thinking
// level. Unlike /new, which resets both to the startup defaults.
//
// pi invalidates the old extension runtime on session replacement, so the
// captured `pi` and command ctx must not be used afterwards. Instead, the
// model is stashed in module state and applied by the session_start handler
// of the freshly loaded extension instance, whose `pi` belongs to the new
// session.

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

type Carried = {
  model: Parameters<ExtensionAPI["setModel"]>[0];
  thinkingLevel?: Parameters<ExtensionAPI["setThinkingLevel"]>[0];
};

let carried: Carried | undefined;

export default function clearExtension(pi: ExtensionAPI) {
  pi.registerCommand("clear", {
    description: "New session, keeping the current model and thinking level",
    handler: async (_args, ctx) => {
      carried = ctx.model
        ? { model: ctx.model, thinkingLevel: ctx.thinkingLevel }
        : undefined;
      const result = await ctx.newSession();
      if (result.cancelled) carried = undefined;
    },
  });

  pi.on("session_start", async (event, ctx) => {
    if (event.reason !== "new" || !carried) return;
    const { model, thinkingLevel } = carried;
    carried = undefined;
    if (!(await pi.setModel(model))) {
      ctx.ui.notify(`Could not restore ${model.id}: provider not authenticated`, "warning");
      return;
    }
    if (thinkingLevel) pi.setThinkingLevel(thinkingLevel);
  });
}
