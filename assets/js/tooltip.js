let TooltipHooks = {};
import {flip, shift, offset, autoUpdate, computePosition} from '@floating-ui/dom'

TooltipHooks.Tooltip = {
  mounted() {
    const tooltipWrapper = this.el
    const button = this.el.querySelector('.tooltip-button');
    const tooltip = this.el.querySelector('.tooltip');

    function update() {
      autoUpdate(button, tooltip, () => {
        computePosition(button, tooltip, {
          placement: 'top',
          middleware: [offset(6), flip({padding: 5}), shift({padding: 5})],
        }).then(({x, y}) => {
          Object.assign(tooltip.style, {
            left: `${x}px`,
            top: `${y}px`,
          });
        });
      })
    }

    function showTooltip() {
      tooltip.style.display = 'block';
      update(); 
    }
     
    function hideTooltip(e) {
      // check if the mouse is still over the button or the tooltip
      console.log(e.relatedTarget == button)
      console.log(e.relatedTarget == tooltip)
      console.log(e.relatedTarget == tooltipWrapper)
      console.log(e.relatedTarget)
      console.log(tooltipWrapper)
      console.log("TEST")
      if (e.relatedTarget !== button && e.relatedTarget !== tooltip && e.relatedTarget !== tooltipWrapper) {
        tooltip.style.display = '';
      }
    }

    [
      ['mouseenter', showTooltip],
      ['mouseleave', hideTooltip],
      ['focus', showTooltip],
      ['blur', hideTooltip],
    ].forEach(([event, listener]) => {
      button.addEventListener(event, listener);
    });

    
  },
}

export { TooltipHooks }