let InlineComposerHooks = {};

function isExpanded(wrapper) {
  const id = wrapper.dataset.domId;
  const slot = wrapper.querySelector(`#inline_full_slot_${id}`);
  if (!slot) return false;
  return slot.classList.contains("grid-rows-[1fr]");
}

function isEmpty(wrapper) {
  const id = wrapper.dataset.domId;
  const full = wrapper.querySelector(`#inline_full_${id}`);
  if (!full) return true;
  const fields = full.querySelectorAll("textarea, input[type=text]");
  for (const el of fields) {
    if (el.value && el.value.trim() !== "") return false;
  }
  return true;
}

function runCollapse(wrapper) {
  const spec = wrapper.dataset.collapseJs;
  if (!spec || !window.liveSocket) return;
  window.liveSocket.execJS(wrapper, spec);
}

function runExpand(wrapper) {
  const spec = wrapper.dataset.expandJs;
  if (!spec || !window.liveSocket) return;
  window.liveSocket.execJS(wrapper, spec);
}

InlineComposerHooks.InlineComposerCollapse = {
  mounted() {
    this.onDocClick = (e) => {
      if (!isExpanded(this.el)) return;
      if (this.el.contains(e.target)) return;
      if (!isEmpty(this.el)) return;
      runCollapse(this.el);
    };
    document.addEventListener("click", this.onDocClick, true);

    this.onReset = () => {
      runCollapse(this.el);
      const replyTo = this.el.dataset.replyToId;
      const ctx = this.el.dataset.contextId;
      if (replyTo && ctx && replyTo !== ctx) {
        this.pushEvent("reset_reply_to", {});
      }
    };
    window.addEventListener("phx:smart_input:reset", this.onReset);

    // Server dispatches this after reply_to_id + portal target update, so the
    // expand runs at the teleport destination — not at the origin mid-move.
    this.onExpand = (e) => {
      if (!e.detail || e.detail.dom_id !== this.el.dataset.domId) return;
      runExpand(this.el);
    };
    window.addEventListener("phx:inline_composer:expand", this.onExpand);
  },

  destroyed() {
    document.removeEventListener("click", this.onDocClick, true);
    window.removeEventListener("phx:smart_input:reset", this.onReset);
    window.removeEventListener("phx:inline_composer:expand", this.onExpand);
  }
};

export { InlineComposerHooks };
