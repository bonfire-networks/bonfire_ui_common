let EmojiHooks = {};

import insertText from 'insert-text-at-cursor';
// import { createPopup } from '@picmo/popup-picker';



EmojiHooks.EmojiPicker = {

  mounted() {
    const trigger = document.querySelector('.emoji-button');
    // trigger.addEventListener('click', () => {
    //   picker.toggle();
    // });

    // const picker = createPopup({}, {
    //   referenceElement: trigger,
    //   triggerElement: trigger,
    //   emojiSize: '1.75rem',
    //   className: 'z-[9999]',
    // });


    // picker.addEventListener('emoji:select', event => {
    //   return event.emoji
    // });

  }

}

export { EmojiHooks }
