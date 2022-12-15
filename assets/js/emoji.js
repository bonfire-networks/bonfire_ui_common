let EmojiHooks = {};

import { Picker } from "emoji-mart";
import insertText from 'insert-text-at-cursor';

EmojiHooks.EmojiPicker = {

    mounted() {
      const picker = new Picker({
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
        },
        data: async () => {
          const response = await fetch(
            "https://cdn.jsdelivr.net/npm/@emoji-mart/data",
          );
  
          return response.json()
        },
      });
      this.el.querySelector("#picker").appendChild(picker);
    
    },
    updated() {
      console.log("emoji updated");
      
    },

}

export { EmojiHooks }