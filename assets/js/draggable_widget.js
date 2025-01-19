import Sortable from "sortablejs";

let DraggableHooks = {};

DraggableHooks.Draggable = {
  mounted() {
    console.log("Mounting sortable on", this.el);
    this.initializeSortable();
  },

  initializeSortable() {
    if (this.el.sortable) return; // Prevent double initialization
    
    const hook = this;
    console.log("Initializing Sortable");
    
    this.el.sortable = new Sortable(this.el, {
      group: this.el.dataset.grouped ? { name: this.el.id } : 'shared',
      animation: 150,
      draggable: "[data-sortable-item]",
      handle: "[data-sortable-handler]",
      ghostClass: "opacity-50",
      chosenClass: "!bg-base-content/5",
      dragClass: "opacity-0",
      forceFallback: true,
      fallbackClass: "sortable-fallback",
      swapThreshold: 0.65,
      invertSwap: true,
      emptyInsertThreshold: 5,
      removeCloneOnHide: true,
      delay: 150,
      delayOnTouchOnly: true,
      
      onEnd: function(evt) {
        if (evt.oldIndex !== evt.newIndex) {
          const item = evt.item;
          const sourceOrder = parseInt(item.dataset.order);
          const sourceItem = item.dataset.item;
          
          const prevItem = item.previousElementSibling;
          const nextItem = item.nextElementSibling;
          
          let targetOrder;
          let position;
          
          if (!prevItem && nextItem) {
            targetOrder = parseInt(nextItem.dataset.order);
            position = "before";
          } else if (prevItem) {
            targetOrder = parseInt(prevItem.dataset.order);
            position = "after";
          }

          const event_name = hook.el.dataset.event;
          const parentItem = hook.el.dataset.parent;

          if (event_name) {
            hook.pushEvent(event_name, {
              source_order: sourceOrder,
              target_order: targetOrder,
              source_item: sourceItem,
              parent_item: parentItem,
              position: position
            });
          }
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