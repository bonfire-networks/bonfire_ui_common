let CopyHooks = {};


CopyHooks.Copy = {
  
  mounted() {
    let { to } = this.el.dataset;
    console.log(to)
    this.el.addEventListener("click", (ev) => {
      ev.preventDefault();
    //   Find the element in the page with that id
        let text = document.getElementById(to).value;
        navigator.clipboard.writeText(text).then(() => {
            console.log("All done again!")
            this.flash("success", "Text copied to clipboard!");
        })
    });

    }
}

export { CopyHooks }