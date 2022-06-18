let FeedHooks = {};

FeedHooks.OpenActivity = {
  mounted() {
    console.log("TEST")
    this.el.addEventListener("click", e => {
      const node_type = e.target.tagName.toLowerCase()  
      const accepted_node_types = ["article", "p"]
      var selection = window.getSelection();
      if (e && (e.button == 0  && accepted_node_types.includes(node_type) && !selection.toString() &&  !e.ctrlKey && !e.metaKey && this.el.dataset.navigate_to_thread == "true")) {
        e.preventDefault();
        this.pushEvent("Bonfire.Social.Feeds:open_activity", {permalink: this.el.dataset.permalink})
      }
  
    }) 
  }
} 

export { FeedHooks }

