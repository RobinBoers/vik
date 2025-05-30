import { EditorView } from "codemirror";
import { EditorState } from "@codemirror/state";

import {
  keymap,
  highlightSpecialChars,
  drawSelection,
  dropCursor,
  rectangularSelection,
  crosshairCursor,
} from "@codemirror/view";

import {
  defaultHighlightStyle,
  syntaxHighlighting,
  indentOnInput,
  bracketMatching,
} from "@codemirror/language";

import {
  autocompletion,
  completionKeymap,
  closeBrackets,
  closeBracketsKeymap,
} from "@codemirror/autocomplete";

import {
  defaultKeymap,
  history,
  historyKeymap,
  indentWithTab,
} from "@codemirror/commands";

import { lintKeymap } from "@codemirror/lint";
import { searchKeymap, highlightSelectionMatches } from "@codemirror/search";

import { elixir } from "codemirror-lang-elixir";
import { espresso } from "thememirror";

import { createPeer } from "./collab";
import { cursorExtension } from "./cursors";

export const Hook = {
  async mounted() {
    const textarea = this.el.querySelector("textarea");
    const target = this.el.querySelector(".target");

    textarea.setAttribute("hidden", true);

    const submitFormWith = (action) => {
      textarea.form.querySelector(`[value=${action}]`).click();
      return true;
    };

    const saveShard = () => submitFormWith("save");
    const deployShard = () => submitFormWith("deploy");

    const keymapping = [
      { key: "Mod-Enter", run: deployShard },
      { key: "Mod-s", run: saveShard, preventDefault: true },
      { key: "Shift-Enter", run: deployShard },
      ...closeBracketsKeymap,
      ...defaultKeymap,
      ...searchKeymap,
      ...historyKeymap,
      ...completionKeymap,
      ...lintKeymap,
      indentWithTab,
    ];

    const extensions = [
      highlightSpecialChars(),
      history(),
      drawSelection(),
      syntaxHighlighting(defaultHighlightStyle, { fallback: true }),
      EditorState.allowMultipleSelections.of(true),
      dropCursor(),
      indentOnInput(),
      bracketMatching(),
      closeBrackets(),
      autocompletion(),
      rectangularSelection(),
      crosshairCursor(),
      highlightSelectionMatches(),
      keymap.of(keymapping),
      elixir(),
      espresso,
    ];

    // ughh, i don't like var but this is literally what var was
    // made to do; in this case i fucking want the bad behaviour.
    if (this.el.hasAttribute("data-suid")) {
      const uid = this.el.dataset.uid || "Anonymous";
      var { doc, collab } = await createPeer(this, uid);

      extensions.push.apply(extensions, collab);
      extensions.push(cursorExtension(uid));
    } else var doc = textarea.value;

    const editor = new EditorView({ parent: target, doc, extensions });

    textarea.form.onsubmit = () => {
      textarea.value = editor.state.doc.toString();
    };

    textarea.onchange = (e) => {
      editor.dispatch({
        changes: {
          from: 0,
          to: editor.state.doc.length,
          insert: e.target.value,
        },
      });
    };
  },
};
