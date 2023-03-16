let EmojiHooks = {};

import insertText from 'insert-text-at-cursor';
import { createPopup } from '@picmo/popup-picker';



EmojiHooks.EmojiPicker = {
  
  mounted() {
    const target_field = document.querySelector(this.el.dataset.targetField || ".composer");

    const trigger = document.querySelector('.emoji-button');
    trigger.addEventListener('click', () => {
      picker.toggle();
    });

    const picker = createPopup({}, {
      referenceElement: trigger,
      triggerElement: trigger,
      emojiSize: '1.8rem',
      className: 'z-[9999]',
    });
    

    picker.addEventListener('emoji:select', event => {
      if (target_field){ 
          // if area is not focused, focus it
          if (!target_field.matches(":focus")) {
            target_field.focus();
          }
      
        // Insert the emoji at the cursor position        
          insertText(target_field, event.emoji + " ")
      
          // close the emojipicker adding style="display: none;"
          // document.querySelector(".emoji-picker").setAttribute("style", "display: none;")
        } else {
            console.log("dunno where to insert the emoji")
        }
    });

    }
}

export { EmojiHooks }