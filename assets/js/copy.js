let CopyHooks = {};

CopyHooks.Copy = {
  
  mounted() {
    let { to } = this.el.dataset;

    this.el.addEventListener("click", (ev) => {
      ev.preventDefault();
      let el;
      let text;
      if (to) {
        el = document.getElementById(to)
      } else {
        el = this.el
      } 
      let link = el.getAttribute("href")
      console.log(link)

      if (link) {
        text = link;
      } else {
        text = el.value;
      }

      if (text !==undefined) {
        navigator.clipboard.writeText(text).then(() => {
          console.log("Copied to clipboard!")
          if (this.flash) {
            this.flash("success", "It's in your clipboard!");
          }
        })
      }
    });

    }
}

export { CopyHooks }

