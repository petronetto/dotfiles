// Ask User - pi extension that registers the `ask_user` tool.
// Opens a focused single-select dialog (title chip, bold question, numbered
// options) instead of asking questions as plain chat text.
// Adapted from pi's shipped examples/extensions/question.ts.

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
  Editor,
  type EditorTheme,
  Key,
  matchesKey,
  Text,
  visibleWidth,
  wrapTextWithAnsi,
} from "@earendil-works/pi-tui";
import { Type } from "typebox";

interface OptionWithDesc {
  label: string;
  description?: string;
}

type DisplayOption = OptionWithDesc & { isOther?: boolean };

interface AskUserDetails {
  title: string;
  question: string;
  options: string[];
  answer: string | null;
  index?: number;
  wasCustom?: boolean;
}

const OptionSchema = Type.Object({
  label: Type.String({ description: "Display label for the option" }),
  description: Type.Optional(Type.String({ description: "Optional description shown below the label" })),
});

const AskUserParams = Type.Object({
  title: Type.String({
    description: "Short contextual title shown as a chip above the question, e.g. 'Scope' or 'Priority'",
  }),
  question: Type.String({ description: "The question to ask the user" }),
  options: Type.Array(OptionSchema, { description: "Options for the user to choose from" }),
});

export default function askUser(pi: ExtensionAPI) {
  pi.registerTool({
    name: "ask_user",
    label: "Ask User",
    description:
      "Ask the user a question in a focused dialog with numbered options. Use this tool whenever you need to ask the user a question, offer choices, or confirm a decision instead of writing the question in prose. Always provide a short contextual title and clear, mutually exclusive options. The user picks an option with arrow keys and Enter (Esc cancels to reply in chat), so prefer this over plain-text questions.",
    parameters: AskUserParams,
    executionMode: "sequential",

    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      if (ctx.mode !== "tui") {
        return {
          content: [{ type: "text", text: "Error: UI not available (running in non-interactive mode)" }],
          details: {
            title: params.title,
            question: params.question,
            options: params.options.map((o) => o.label),
            answer: null,
          } as AskUserDetails,
        };
      }

      if (params.options.length === 0) {
        return {
          content: [{ type: "text", text: "Error: No options provided" }],
          details: { title: params.title, question: params.question, options: [], answer: null } as AskUserDetails,
        };
      }

      const allOptions: DisplayOption[] = [...params.options, { label: "Type something.", isOther: true }];

      const result = await ctx.ui.custom<{ answer: string; wasCustom: boolean; index?: number } | null>(
        (tui, theme, _kb, done) => {
          let optionIndex = 0;
          let editMode = false;
          let cachedLines: string[] | undefined;

          const editorTheme: EditorTheme = {
            borderColor: (s) => theme.fg("accent", s),
            selectList: {
              selectedPrefix: (t) => theme.fg("accent", t),
              selectedText: (t) => theme.fg("accent", t),
              description: (t) => theme.fg("muted", t),
              scrollInfo: (t) => theme.fg("dim", t),
              noMatch: (t) => theme.fg("warning", t),
            },
          };
          const editor = new Editor(tui, editorTheme);

          editor.onSubmit = (value) => {
            const trimmed = value.trim();
            if (trimmed) {
              done({ answer: trimmed, wasCustom: true });
            } else {
              editMode = false;
              editor.setText("");
              refresh();
            }
          };

          function refresh() {
            cachedLines = undefined;
            tui.requestRender();
          }

          function handleInput(data: string) {
            if (editMode) {
              if (matchesKey(data, Key.escape)) {
                editMode = false;
                editor.setText("");
                refresh();
                return;
              }
              editor.handleInput(data);
              refresh();
              return;
            }

            if (matchesKey(data, Key.up)) {
              optionIndex = Math.max(0, optionIndex - 1);
              refresh();
              return;
            }
            if (matchesKey(data, Key.down)) {
              optionIndex = Math.min(allOptions.length - 1, optionIndex + 1);
              refresh();
              return;
            }
            if (matchesKey(data, Key.enter)) {
              const selected = allOptions[optionIndex];
              if (selected.isOther) {
                editMode = true;
                refresh();
              } else {
                done({ answer: selected.label, wasCustom: false, index: optionIndex + 1 });
              }
              return;
            }
            if (matchesKey(data, Key.escape)) {
              done(null);
            }
          }

          function render(width: number): string[] {
            if (cachedLines) return cachedLines;

            const lines: string[] = [];
            const renderWidth = Math.max(1, width);

            function addWrapped(text: string) {
              lines.push(...wrapTextWithAnsi(text, renderWidth));
            }

            function addWrappedWithPrefix(prefix: string, text: string) {
              const prefixWidth = visibleWidth(prefix);
              if (prefixWidth >= renderWidth) {
                addWrapped(prefix + text);
                return;
              }
              const wrapped = wrapTextWithAnsi(text, renderWidth - prefixWidth);
              const continuationPrefix = " ".repeat(prefixWidth);
              for (let i = 0; i < wrapped.length; i++) {
                lines.push(`${i === 0 ? prefix : continuationPrefix}${wrapped[i]}`);
              }
            }

            lines.push(theme.fg("accent", "─".repeat(renderWidth)));
            addWrappedWithPrefix(" ", theme.bg("selectedBg", theme.fg("text", ` ${params.title} `)));
            lines.push("");
            addWrappedWithPrefix(" ", theme.fg("text", theme.bold(params.question)));
            lines.push("");

            for (let i = 0; i < allOptions.length; i++) {
              const opt = allOptions[i];
              const selected = i === optionIndex;
              const isOther = opt.isOther === true;
              const prefix = selected ? theme.fg("accent", "❯ ") : "  ";
              const label = `${i + 1}. ${opt.label}${isOther && editMode ? " ✎" : ""}`;
              const color = selected || (isOther && editMode) ? "accent" : "text";
              addWrappedWithPrefix(prefix, theme.fg(color, label));
              if (opt.description) {
                addWrappedWithPrefix("     ", theme.fg("muted", opt.description));
              }
            }

            if (editMode) {
              lines.push("");
              addWrappedWithPrefix(" ", theme.fg("muted", "Your answer:"));
              for (const line of editor.render(Math.max(1, renderWidth - 2))) {
                lines.push(` ${line}`);
              }
            }

            lines.push("");
            if (editMode) {
              addWrappedWithPrefix(" ", theme.fg("dim", "Enter to submit · Esc to go back"));
            } else {
              addWrappedWithPrefix(" ", theme.fg("dim", "Enter to select · ↑/↓ to navigate · Esc to cancel"));
            }
            lines.push(theme.fg("accent", "─".repeat(renderWidth)));

            cachedLines = lines;
            return lines;
          }

          return {
            render,
            invalidate: () => {
              cachedLines = undefined;
            },
            handleInput,
          };
        },
      );

      const simpleOptions = params.options.map((o) => o.label);

      if (!result) {
        return {
          content: [{ type: "text", text: "User cancelled the selection" }],
          details: {
            title: params.title,
            question: params.question,
            options: simpleOptions,
            answer: null,
          } as AskUserDetails,
        };
      }

      if (result.wasCustom) {
        return {
          content: [{ type: "text", text: `User wrote: ${result.answer}` }],
          details: {
            title: params.title,
            question: params.question,
            options: simpleOptions,
            answer: result.answer,
            wasCustom: true,
          } as AskUserDetails,
        };
      }

      return {
        content: [{ type: "text", text: `User selected: ${result.index}. ${result.answer}` }],
        details: {
          title: params.title,
          question: params.question,
          options: simpleOptions,
          answer: result.answer,
          index: result.index,
          wasCustom: false,
        } as AskUserDetails,
      };
    },

    renderCall(args, theme, _context) {
      let text = theme.fg("toolTitle", theme.bold("ask_user ")) + theme.fg("muted", args.question);
      const opts = Array.isArray(args.options) ? args.options : [];
      if (opts.length) {
        const labels = opts.map((o: OptionWithDesc) => o.label);
        const numbered = [...labels, "Type something."].map((o, i) => `${i + 1}. ${o}`);
        text += `\n${theme.fg("dim", `  Options: ${numbered.join(", ")}`)}`;
      }
      return new Text(text, 0, 0);
    },

    renderResult(result, _options, theme, _context) {
      const details = result.details as AskUserDetails | undefined;
      if (!details) {
        const text = result.content[0];
        return new Text(text?.type === "text" ? text.text : "", 0, 0);
      }

      if (details.answer === null) {
        return new Text(theme.fg("warning", "Cancelled"), 0, 0);
      }

      if (details.wasCustom) {
        return new Text(
          theme.fg("success", "✓ ") + theme.fg("muted", "(wrote) ") + theme.fg("accent", details.answer),
          0,
          0,
        );
      }

      const display = details.index ? `${details.index}. ${details.answer}` : details.answer;
      return new Text(theme.fg("success", "✓ ") + theme.fg("accent", display), 0, 0);
    },
  });
}
