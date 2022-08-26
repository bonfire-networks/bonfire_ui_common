let FeedHooks = {};

FeedHooks.PreviewActivity = {
  mounted() {
    this.el.addEventListener("click", e => {
      e.preventDefault(); // TODO: find a better way to hook a simple event on an anchor without needing a hook
      uri = this.el.dataset.permalink
      // this.pushEvent("Bonfire.Social.Feeds:open_activity", { id: this.el.dataset.id, permalink: uri })
      const layout = document.getElementById("bonfire_layout")
      let previous_scroll = null
      if (layout) {
        previous_scroll = layout.scrollTop
      }

      history.pushState(
        {
          'previous_url': document.location.href,
          'previous_scroll': previous_scroll
        },
        '',
        uri)
    })
  }
} 

FeedHooks.ClosePreview = {
  mounted() {
    this.el.addEventListener("click", e => {
      location_before_preview = history.state["previous_url"]
      previous_scroll = history.state["previous_scroll"]
      console.log(previous_scroll)
      if (location_before_preview) {
        history.pushState({}, '', location_before_preview)
      }
      if (previous_scroll) {
        const layout = document.getElementById("bonfire_layout")
        layout.scrollTo({top: previous_scroll, behavior: 'instant'})
        // window.scrollTo(0, previous_scroll);
      }
    })
  }
}


FeedHooks.OpenActivity = {
  mounted() {
    this.el.addEventListener("click", e => {
      const accepted_node_types = ["div", "article", "p", "h1", "h2", "h3", "h4", "h5", "strong", "em", "blockquote"]
      // const excluded_node_types = ["a", "button", "svg", "path", "span"]
      // console.log(e.target.tagName.toLowerCase())
      if (e && (e.button == 0 && this.el.dataset.navigate_to_thread == "true" && (accepted_node_types.includes(e.target.tagName.toLowerCase()) || e.target.classList.contains("feed-clickable")) && !window.getSelection().toString() && !e.ctrlKey && !e.metaKey)) {
        e.preventDefault();
        this.pushEvent("Bonfire.Social.Feeds:open_activity", { permalink: this.el.dataset.permalink })
      }
    })
  }
} 

export { FeedHooks }

