// This hooks slows down the form submit to prevent flickering
// buttons. Written by @marcofiset on the Elixir forum:
// https://elixirforum.com/t/39831/7
//
// Modified by me to be compatible with the latest LiveView.
export const Hook = {
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

export function onBeforeUpdate(from, to) {
  const prop = "data-update-ignore";
  const ignored = from.hasAttribute(prop) ? 
    from.getAttribute(prop).split(" ") : [];

  const defaults = ["data-submit-loading"];
  ignored.concat(defaults).forEach(attr => {
    if(from.hasAttribute(attr))
      to.setAttribute(attr, from.getAttribute(attr));
  });
}
