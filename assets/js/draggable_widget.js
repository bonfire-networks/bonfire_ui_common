import Sortable from "sortablejs";

let DraggableHooks = {};

DraggableHooks.Draggable = {
  mounted() {
    this.initializeSortable();
  },

  initializeSortable() {
    if (this.el.sortable) return; // Prevent double initialization
    
    const hook = this;
    
    this.el.sortable = new Sortable(this.el, {
      animation: 150,
      delay: 100,
      dragClass: "drag-item",
      ghostClass: "drag-ghost",
      draggable: "[data-sortable-item]",
      handle: "[data-sortable-handler]",
      onEnd: e => {
        const params = {
          old_index: e.oldIndex,
          new_index: e.newIndex,
          parent_item: hook.el.dataset.parent,
          source_item: e.item.dataset.item,
          target_order: [...e.target.children].map(el => el.dataset.item)
        };
        
        // Event should be "reorder_widget" or "reorder_sub_widget"
        const event_name = hook.el.dataset.event;
        if (event_name) {
          hook.pushEventTo(hook.el, event_name, params);
        }
      }
    });
  },

  destroyed() {
    if (this.el.sortable) {
      this.el.sortable.destroy();
      this.el.sortable = null;
    }
  }
};

export { DraggableHooks };
