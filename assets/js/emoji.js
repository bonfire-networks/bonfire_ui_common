let EmojiHooks = {};

import { Picker } from "emoji-mart";
import insertText from 'insert-text-at-cursor';
import data from '@emoji-mart/data'

EmojiHooks.EmojiPicker = {

    mounted() {
      const picker = new Picker({
        data: data,
        emojiButtonSize: 30,
        emojiSize: 20,
        previewPosition: "none",
        onEmojiSelect: function (emoji) {
          
          // Insert the emoji at the cursor position
          const area = document.querySelector(".composer");
          
          // if area is not focused, focus it
          if (!area.matches(":focus")) {
            area.focus();
          }

          insertText(area, emoji.native + " ")

          // close the emojipicker adding style="display: none;"
          // document.querySelector(".emoji-picker").setAttribute("style", "display: none;")
        }
        
      });
      // wait 1 second and append the picker to the DOM
      setTimeout(() => {
        this.el.querySelector("#picker").appendChild(picker);
      }, 2000);
    
    },
    updated() {
      console.log("emoji updated");
      // load the emoji picker
      const picker = new Picker({
        data: data,
        emojiButtonSize: 30,
        emojiSize: 20,
        previewPosition: "none",
        onEmojiSelect: function (emoji) {
          // Insert the emoji at the cursor position
          const area = document.querySelector(".composer");
          insertText(area, emoji.native + " ")
        }
      });
      this.el.querySelector("#picker").appendChild(picker);
    },

}

export { EmojiHooks }