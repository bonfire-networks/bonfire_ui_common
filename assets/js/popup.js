let PopupHooks = {};
import { computePosition, detectOverflow, flip, shift, offset } from "@floating-ui/dom";


// run to load previously chosen theme when first loading any page (note: not need if using data-theme param on HTML wrapper instead)
// themeChange()

PopupHooks.Popup = {

    mounted() {
      const reference = this.el.querySelector("label");
      const floating = this.el.querySelector("ul");
      console.log("reference", reference);
      console.log("floating", floating);

      const middleware = {
        name: 'middleware',
        async fn(middlewareArguments) {
          const overflow = await detectOverflow(middlewareArguments);
          return {};
        },
      };

      computePosition(reference, floating, {
         middleware: [offset(6), flip(), shift({padding: 5}) ]
       }).then(({ x, y, overflow }) => {
        console.log("x", x);
        console.log("y", y);
        console.log("overflow", overflow);
         Object.assign(floating.style, {
           top: `${y}px`,
           left: `${x}px`
         });
       });
    },
    updated() {
      const reference = this.el.querySelector("label");
      const floating = this.el.querySelector("ul");
      console.log("reference", reference);
      console.log("floating", floating);

      computePosition(reference, floating, {
         middleware: [flip()]
       }).then(({ x, y }) => {
        console.log("x", x);
        console.log("y", y);
        console.log("overflow", overflow);

         Object.assign(floating.style, {
           top: `${y}px`,
           left: `${x}px`
         });
       });
    }

}

export { PopupHooks }