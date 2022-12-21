let PopupHooks = {};
import tippy from 'tippy.js';


// run to load previously chosen theme when first loading any page (note: not need if using data-theme param on HTML wrapper instead)
// themeChange()

PopupHooks.Popup = {

    mounted() {

      // Instanciate tippy
      const template = this.el.querySelector('.template');
      const instance = tippy(this.el.querySelector('.tippy'), {
        content: template.innerHTML,
        arrow: false,
        animation: 'shift-away',
        theme: 'translucent',
        interactive: true,
        allowHTML: true,
      }); 



    },


}

export { PopupHooks }