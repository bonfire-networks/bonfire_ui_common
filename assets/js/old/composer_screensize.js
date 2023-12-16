
// import { disableBodyScroll, enableBodyScroll } from 'body-scroll-lock';

let ComposerHooks = {};

ComposerHooks.ScreenSize = {
  mounted() {
    const composer = this.el
    const gutter = composer.querySelector("#gutter");
    const composerWrapper = document.getElementById("composer_wrapper");
    const composer_body = document.getElementById("write_post_body_field");

    // boundaries general
    const boundaries_general = composerWrapper.getElementsByClassName("boundaries_general_access")[0];
    // boundaries preview
    const boundaries_preview = document.getElementById("preview_boundaries_container");
    // set boundaries
    // const set_boundaries = document.getElementById("set_boundaries");
    const set_boundaries = composerWrapper.getElementsByClassName("set_boundaries")[0];


    // function resizer(e) {
    //   disableBodyScroll(document.body);
    //   document.body.style.userSelect = 'none';
    //   window.addEventListener('mousemove', mousemove);
    //   window.addEventListener('mouseup', mouseup);
    //   let prevy = e.y;
    //   const leftPanel = composer.getBoundingClientRect();

    //   function mousemove(e) {
    //     document.body.style.cursor = 'row-resize';
    //     let newY = prevy - e.y;
    //     composer.style.height = leftPanel.height + newY + "px";

    //     // programmatically remove 48px from the composer_body max height
    //     composer_body.style.maxHeight = composer_body.getBoundingClientRect().height - 48 + "px";

    //     // console.log(smartInput.getBoundingClientRect().height)
    //     // smartInput.style.height = smartInput.getBoundingClientRect().height - 60 + "px";
    //     // console.log(smartInput.style.height)
    //     // milkdown.style.height = composer.getBoundingClientRect().height - 110 - 108 + "px";
    //     // composerWrapper.style.height = composer.getBoundingClientRect().height - 32 - 52  + "px";
    //     // boundaries_general.style.height = composer.getBoundingClientRect().height - 32 - 64 + "px";
    //     boundaries_preview.style.height = composer.getBoundingClientRect().height - 32 - 64 + "px";
    //     set_boundaries.style.height = composer.getBoundingClientRect().height - 32 - 64 + "px";
    //   }

    //   function mouseup() {
    //     enableBodyScroll(document.body);
    //     document.body.style.userSelect = 'auto';
    //     document.body.style.cursor = 'auto';
    //     window.removeEventListener('mousemove', mousemove);
    //     window.removeEventListener('mouseup', mouseup);

    //   }
    // }

    // gutter.addEventListener('mousedown', resizer);


    // window.addEventListener("resize", (e) => {
    //   if (window.innerWidth < 768) {
    //     composer.style.height = "100%";
    //     // composerWrapper.style.height = composer.getBoundingClientRect().height - 54 - 52 - 42 + "px";
    //   } else {
    //     // composerWrapper.style.height = composer.getBoundingClientRect().height - 54 - 52 - 42 + "px";
    //   }
    // });

    // if (window.innerWidth < 768) {
    //   // composerWrapper.style.height = composer.getBoundingClientRect().height - 54 - 52 - 42 + "px";
    // }
  },
  updated() {
    const composer = this.el
    const composerWrapper = document.getElementById("composer_wrapper");
    // composerWrapper.style.height = composer.getBoundingClientRect().height - 54 - 52 - 42 + "px";

  }
}


export { ComposerHooks }
