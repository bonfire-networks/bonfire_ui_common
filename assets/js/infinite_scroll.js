let InfiniteScrollHooks = {};

InfiniteScrollHooks.InfiniteScroll = {
  
  page() { return this.el.dataset.page; },
  getPhxValues(el) {
    return el
    .getAttributeNames()
    .filter(name => name.startsWith("phx-value-"))
    .reduce((obj, name) => ({
      ...obj,
      [name.substring(10)]: el.getAttribute(name)
    }), {})
  },
  loadMore(entries) {
    const target = entries[0];
    // console.log(this.el.dataset.entryCount)
    if (target.isIntersecting && this.pending == this.page()) {
      let entryCount = this.el.dataset.entryCount
      if (undefined == entryCount || entryCount < 1) {
        let event = this.el.getAttribute("phx-scroll")
        if (event) {
          this.el.getElementsByTagName("a")[0].innerHTML = "Loading more...";
          this.pending = this.page() + 1;
          this.pushEventTo(this.el.getAttribute("phx-target"), event, this.getPhxValues(this.el));
        } else {
          console.log("skip loading more because no phx-scroll event")
        }
      } else {
        console.log("skip loading more")
      }
    }
  },
  mounted() {
    this.pending = this.page();
    this.observer = new IntersectionObserver(
      (entries) => this.loadMore(entries),
      {
        root: null, // window by default
        rootMargin: "400px",
        threshold: 0.1,
      }
    );
    this.observer.observe(this.el);

    this.el.addEventListener("click", e => {
      if (this.el.dataset.entryCount > 0) {
        for (let element of document.getElementsByClassName("infinite_scroll_hidden")) {
          element.style.display = "block";
        }
        this.el.getElementsByTagName("a")[0].innerHTML = "Load more";
        this.el.dataset.entryCount = 0;
        e.preventDefault();
      }
      
    });
  },
  destroyed() {
    this.observer.unobserve(this.el);
  },
  updated() {
    this.pending = this.page();
  },
}

export { InfiniteScrollHooks }
