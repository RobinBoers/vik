import "phoenix_html";
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";

import topbar from "topbar";

import { Hook as CodeMirror } from "./codemirror";
import { Hook as Scroll } from "./scroll";
import { Hook as Shell } from "./shell";
import { Hook as SlowSubmit } from "./forms";

import { onBeforeUpdate } from "./forms";

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  metadata: { keydown: (e, _) => ({ ctrl: e.ctrlKey || e.metaKey }) },
  hooks: { CodeMirror, Scroll, Shell, SlowSubmit },
  dom: { onBeforeElUpdated: onBeforeUpdate },
});

topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });

window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

liveSocket.connect();

// liveSocket.enableDebug();
// liveSocket.enableLatencySim(1000); // enabled for duration of browser session
// liveSocket.disableLatencySim();

window.liveSocket = liveSocket;
