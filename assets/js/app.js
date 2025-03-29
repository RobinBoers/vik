import "phoenix_html";
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";

let Hooks = {};

Hooks.Scroll = {
  updated() {
    this.el.scrollTop = this.el.scrollHeight;
  }
};

// This hooks slows down the form submit to prevent flickering
// buttons. Written by @marcofiset on the Elixir forum:
// https://elixirforum.com/t/39831/7
//
// Modified by me to be compatible with the latest LiveView.
Hooks.SlowSubmit = {
  mounted() {
    this.el.addEventListener("submit", (e) => this.handleSubmit(e));
  },

  handleSubmit(event) {
    // That's the key element that my previous implementation was missing!
    // Since the element is re-rendered, I need to set the class again if
    // we're still submitting.

    this.setSubmitting(event);

    const wait = new Promise((resolve, reject) => {
      setTimeout(() => resolve(), this.el.dataset.minLoadingTime || 500);
    });

    const loading = new Promise((resolve, reject) => {
      window.addEventListener("phx:page-loading-stop", () => resolve(), {
        once: true,
      });
    });

    Promise.all([wait, loading]).then(() => this.stopSubmitting(event));
  },

  setSubmitting(event) {
    this.submitting = true;
    this.el.setAttribute("data-submit-loading", true);

    event.submitter.querySelectorAll("[data-disable-with]").forEach((el) => {
      const html = el.innerHTML;
      el.innerText = el.getAttribute("data-disable-with");
      el.setAttribute("data-disable-with", html);
    });
  },

  stopSubmitting(event) {
    this.submitting = false;
    this.el.removeAttribute("data-submit-loading");

    event.submitter.querySelectorAll("[data-disable-with]").forEach((el) => {
      const html = el.getAttribute("data-disable-with");
      el.setAttribute("data-disable-with", el.innerText);
      el.innerHTML = html;
    });
  },
};

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
  dom: {
    onBeforeElUpdated(from, to) {
      const prop = "data-update-ignore";
      const ignored = from.hasAttribute(prop) ? 
        from.getAttribute(prop).split(" ") : [];
    
      const defaults = ["data-submit-loading"];
      ignored.concat(defaults).forEach(attr => {
        if(from.hasAttribute(attr))
          to.setAttribute(attr, from.getAttribute(attr));
      });
    }
  }
});

topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

liveSocket.connect();

// liveSocket.enableDebug();
// liveSocket.enableLatencySim(1000); // enabled for duration of browser session
// liveSocket.disableLatencySim();

window.liveSocket = liveSocket;
