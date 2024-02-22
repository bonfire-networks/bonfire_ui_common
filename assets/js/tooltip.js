import { flip, shift, offset, autoUpdate, computePosition } from '@floating-ui/dom'
let TooltipHooks = {};

TooltipHooks.Tooltip = {
  mounted() {
    const tooltipWrapper = this.el
    // save as a variable the data-position attribute of the tooltipWrapper
    const position = tooltipWrapper.getAttribute('data-position')
    const button = this.el.querySelector('.tooltip-button');
    const tooltip = this.el.querySelector('.tooltip');

    function update() {
      autoUpdate(button, tooltip, () => {
        computePosition(button, tooltip, {
          // Set the position of the tooltip based on the data-position attribute or "top" if not provided
          placement: position || 'top',
          middleware: [offset(6), flip({ padding: 5 }), shift({ padding: 5 })],
        }).then(({ x, y }) => {
          Object.assign(tooltip.style, {
            left: `${x}px`,
            top: `${y}px`,
          });
        });
      })
    }

    // toggle tooltip on click
    // function showTooltip() {
    //   tooltip.style.display = 'block';
    //   update();
    // }
    // function hideTooltip() {
    //   tooltip.style.display = '';
    // }



    function toggleTooltip() {
      console.log("eeeeeeeee")
      if (tooltip.style.display === 'block') {
        console.log("NO ERRORE")
        tooltip.style.display = '';
      } else {
        console.log("QUI")
        tooltip.style.display = 'block';
        update();
      }
    }

    // Hide tooltip if user clicks outside of it
    document.addEventListener('click', (event) => {
      const isClickInsideTooltip = tooltip.contains(event.target);
      const isClickOnButton = button.contains(event.target);
      if (!isClickInsideTooltip && !isClickOnButton && tooltip.style.display === 'block') {
        tooltip.style.display = '';
      }
    });

    [
      ['click', toggleTooltip],
      // ['mouseleave', hideTooltip],
      // ['focus', showTooltip],
      // ['blur', hideTooltip],
    ].forEach(([event, listener]) => {
      button.addEventListener(event, listener);
    });

  },
}

export { TooltipHooks }
