let EmojiHooks = {};

import { Picker } from "emoji-mart";
import insertText from 'insert-text-at-cursor';
// import data from '@emoji-mart/data'


EmojiHooks.EmojiPicker = {
  
  mounted() {
    const target_field = document.querySelector(this.el.dataset.targetField || ".composer");
    const picker = new Picker({
      data: async() => {
        const response = await fetch(
          'https://cdn.jsdelivr.net/npm/@emoji-mart/data/sets/14/native.json',
        )
        return response.json()
      },
      emojiButtonSize: 30,
      emojiSize: 20,
      previewPosition: "none",
      set: "native",
      onEmojiSelect: function (emoji) {
        
        if (target_field){ 
          // if area is not focused, focus it
          if (!target_field.matches(":focus")) {
            target_field.focus();
          }
      
        // Insert the emoji at the cursor position        
          insertText(target_field, emoji.native + " ")
      
          // close the emojipicker adding style="display: none;"
          // document.querySelector(".emoji-picker").setAttribute("style", "display: none;")
        } else {
            console.log("dunno where to insert the emoji")
        }
      }
      
    });

    // wait for the data to be loaded correctly before appending the picker
    this.el.querySelector(".picker").appendChild(picker);

    
    }
}

export { EmojiHooks }