let FeedHooks = {};

FeedHooks.PreviewActivity = {
  mounted() {
    this.el.addEventListener("click", e => {
      e.preventDefault(); // TODO: find a better way to hook a simple event on an anchor without needing a hook
      uri = this.el.dataset.permalink
      // this.pushEvent("Bonfire.Social.Feeds:open_activity", { id: this.el.dataset.id, permalink: uri })
      const layout = document.getElementById("root")
      const main = document.getElementById("inner")
      console.log("inner")
      main.classList.add("hidden")
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
      const layout = document.getElementById("root")
      const main = document.getElementById("inner")
      console.log("TEST")
      location_before_preview = history.state["previous_url"]
      previous_scroll = history.state["previous_scroll"]
      main.classList.remove("hidden")
      if (location_before_preview) {
        console.log("qui")
        console.log(location_before_preview)
        history.pushState({}, '', location_before_preview)
      }
      console.log(previous_scroll)
      if (previous_scroll) {
        console.log("qui2")
        layout.scrollTo({top: previous_scroll, behavior: 'instant'})
        // window.scrollTo(0, previous_scroll);
      }
    })
  }
}

export { FeedHooks }

