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

      if (text !== undefined) {
        navigator.clipboard.writeText(text).then(() => {
          let msg = "Copied!";
          console.log(msg)
          if (this.flash) {
            this.flash("success", msg);
          } else {
            let label = el.querySelector('[data-role="label"]')
            if (label) {
              label.innerHTML = msg;
            } else {
              // add a tooltip next the element that says "copied!" and disappear after 3 seconds
              this.el.setAttribute("data-tip", msg);
              this.el.classList.add("tooltip", "tooltip-open");

            }
          }
        })
      }

      setTimeout(() => {
        this.el.removeAttribute("data-tooltip");
        this.el.classList.remove("tooltip", "tooltip-open");
      }, 3000);
    });

  }
}

export { CopyHooks }
