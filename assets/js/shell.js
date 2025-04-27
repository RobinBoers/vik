// Clears input on submit and retains hist of entered expressions
// in localStorage, and cycles through them with the arrow keys.

export const Hook = {
  mounted() {
    const retainhist = (hist) => {
      localStorage.setItem("shell-hist", JSON.stringify(hist));
    }
    
    const restorehist = () => {
      const stored = localStorage.getItem("shell-hist");
      console.log(stored);
      return stored ? JSON.parse(stored) : [];
    }

    const hist = restorehist();
    let head = hist.length;

    this.el.onkeydown = (e) => {
      if(e.key == 'Enter') {
        e.preventDefault();
        this.pushEvent("execute", { source: this.el.value });
        hist.push(this.el.value);
        head = hist.length;
        this.el.value = "";
        retainhist(hist);
      }
      else if(e.key == 'ArrowUp' && head > 0) {
        e.preventDefault();
        head -= 1;        
        this.el.value = hist[head];
      }
      else if(e.key == 'ArrowDown' && head < hist.length - 1) {
        e.preventDefault();
        head += 1;
        this.el.value = hist[head];
      }
      else if(e.key == 'ArrowDown') {
        e.preventDefault();
        head = hist.length;
        this.el.value = "";
      }
    };
  }
};
