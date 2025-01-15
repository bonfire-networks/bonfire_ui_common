import Sortable from "sortablejs";

let DraggableHooks = {};

DraggableHooks.Draggable = {
  mounted() {
    const hook = this;
    console.log("Mounting sortable on", this.el);
    
    if (!this.el.sortable) {
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
        
        setData: function (dataTransfer, dragEl) {
          // Store the original background class
          dragEl.setAttribute('data-original-bg', dragEl.className);
        },
        
        onChoose: function (evt) {
          evt.item.classList.add('!bg-base-content/5');
        },
        
        onStart: function(evt) {
          evt.item.style.visibility = 'hidden';
        },

        onEnd: function(evt) {
          evt.item.style.visibility = '';
          evt.item.classList.remove('!bg-base-content/5');
          
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

            const event_name = this.el.dataset.event;
            const parentItem = this.el.dataset.parent;
            
            if (targetOrder !== undefined && sourceOrder !== targetOrder) {
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