import Sortable from "sortablejs";

let DraggableHooks = {};

DraggableHooks.Draggable = {
  mounted() {
    this.initializeSortable();
  },

  initializeSortable() {
    if (this.el.sortable) return; // Prevent double initialization

    // Disable dragging on touch devices, where it fights scrolling, unless the list drags by a handle only (`data-sortable-touch`)
    const isTouchDevice = 'ontouchstart' in window || navigator.maxTouchPoints > 0;
    if (isTouchDevice && !("sortableTouch" in this.el.dataset)) return;

    const hook = this;

    const options = {
      animation: 150,
      delay: 100,
      dragClass: "drag-item",
      ghostClass: "drag-ghost",
      draggable: "[data-sortable-item]",
      handle: "[data-sortable-handler]",
      onEnd: e => {
        // `e.to` is the list the item was dropped in, which is the list it started in unless lists share a group
        const params = {
          old_index: e.oldIndex,
          new_index: e.newIndex,
          parent_item: hook.el.dataset.parent,
          source_item: e.item.dataset.item,
          target_parent: e.to.dataset.parent,
          target_order: [...e.to.children].map(el => el.dataset.item)
        };

        // Event should be "reorder_widget" or "reorder_sub_widget"
        const event_name = hook.el.dataset.event;
        if (event_name) {
          // a refused drop: put the item back, since an unchanged render sends no patch
          hook.pushEventTo(hook.el, event_name, params, reply => {
            if (reply && reply.refused) e.from.insertBefore(e.item, e.from.children[e.oldIndex] || null);
          });
        }
      }
    };

    // lists that share a `data-sortable-group` accept each other's items; with none, a list only reorders its own
    if (this.el.dataset.sortableGroup) options.group = this.el.dataset.sortableGroup;

    this.el.sortable = new Sortable(this.el, options);
  },

  destroyed() {
    if (this.el.sortable) {
      this.el.sortable.destroy();
      this.el.sortable = null;
    }
  }
};

export { DraggableHooks };
