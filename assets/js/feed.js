let FeedHooks = {};

FeedHooks.OpenActivity = {
  mounted() {
    this.el.addEventListener("click", e => {
      const accepted_node_types = ["article", "p", "h1", "h2", "h3", "h4", "h5", "strong", "em", "blockquote"]
      // const excluded_node_types = ["a", "button", "svg", "path", "span"]
      // console.log(e.target.tagName.toLowerCase())
      if (e && (e.button == 0 && this.el.dataset.navigate_to_thread == "true" && (accepted_node_types.includes(e.target.tagName.toLowerCase()) || e.target.classList.contains("feed-clickable")) && !window.getSelection().toString() && !e.ctrlKey && !e.metaKey)) {
        e.preventDefault();
        this.pushEvent("Bonfire.Social.Feeds:open_activity", {permalink: this.el.dataset.permalink})
      }
    }) 
  }
} 

export { FeedHooks }

