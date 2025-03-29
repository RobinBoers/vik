// When attached via phx-hook="Scroll",
// will auto-scroll to the bottom of an element
// on every DOM update.

export const Hook = {
  updated() {
    this.el.scrollTop = this.el.scrollHeight;
  }
};
