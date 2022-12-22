let FeedHooks = {};

FeedHooks.PreviewActivity = {
  mounted() {
    this.el.addEventListener("click", e => {
      e.preventDefault(); // TODO: find a better way to hook a simple event on an anchor without needing a hook
      console.log("PreviewActivity clicked")

      let uri = this.el.dataset.permalink

      // push event to load up the PreviewContent
      this.pushEventTo(this.el, "open", {}) 

      let previous_scroll = null
      // this.pushEvent("Bonfire.Social.Feeds:open_activity", { id: this.el.dataset.id, permalink: uri })
      const layout = document.getElementById("root")
      const main = document.getElementById("inner")
      const preview_content = document.getElementById("preview_content")
      if (preview_content) {
        preview_content.classList.remove("hidden")
      }
      if (main) {
        main.classList.add("hidden")
      }
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

    const back = function () {
      const layout = document.getElementById("root")
      const main = document.getElementById("inner")
      const preview_content = document.getElementById("preview_content")
      if (preview_content) {
        preview_content.classList.add("hidden")
      }
      if (history.state) {
        location_before_preview = history.state["previous_url"]
        previous_scroll = history.state["previous_scroll"]
        main.classList.remove("hidden")
        console.log(location_before_preview)
        if (location_before_preview) {
          history.pushState({}, '', location_before_preview)
        }
        console.log(previous_scroll)
        if (previous_scroll) {
          layout.scrollTo({ top: previous_scroll, behavior: 'instant' })
          // window.scrollTo(0, previous_scroll);
        }
      }
    }

    // close button
    this.el.addEventListener("click", e => {
      console.log("click - attempt going back")
      back()
    })

    // intercept browser "back" action
    window.addEventListener("popstate", e => {
      console.log("popstate - attempt going back")
      console.log(e)
      // e.preventDefault();
      this.pushEvent("Bonfire.UI.Common.OpenPreviewLive:close", {})
      back();
    })
  }
}

export { FeedHooks }

