import Sortable from "sortablejs";

let DraggableHooks = {};

DraggableHooks.Draggable = {
  mounted() {
    const hook = this;
    console.log("Mounting sortable on", this.el);
    
    if (!this.el.sortable) {
      console.log("Initializing Sortable");
      this.el.sortable = new Sortable(this.el, {
        group: 'shared',
        animation: 150,
        draggable: "[data-sortable-item]",
        handle: "[data-sortable-handler]",
        ghostClass: "opacity-50",
        chosenClass: "bg-base-content/5",
        dragClass: "opacity-0",
        forceFallback: true,
        fallbackClass: "sortable-fallback",
        swapThreshold: 0.65,
        invertSwap: true,
        emptyInsertThreshold: 5,
        removeCloneOnHide: true,
        
        onStart: function(evt) {
          // Hide original element during drag
          evt.item.style.visibility = 'hidden';
        },

        onEnd: function(evt) {
          // Restore visibility
          evt.item.style.visibility = '';
          
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
            
            console.log("HERE")
            console.log(targetOrder)
            console.log(sourceOrder)     
            if (targetOrder !== undefined && sourceOrder !== targetOrder) {
              hook.pushEvent("Bonfire.Social.Feeds.LiveHandler:reorder_widget", {
                source_order: sourceOrder,
                target_order: targetOrder,
                source_item: sourceItem,
                position: position
              });
            }
          }
        }
      });
    }
  },

  destroyed() {
    if (this.el.sortable) {
      this.el.sortable.destroy();
      delete this.el.sortable;
    }
  }
};


export { DraggableHooks };