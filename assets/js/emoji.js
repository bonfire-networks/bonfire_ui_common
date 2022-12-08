let EmojiHooks = {};

import { Picker } from "emoji-mart";
import insertText from 'insert-text-at-cursor';

EmojiHooks.EmojiPicker = {

    mounted() {
      // const picker = new Picker({
      //   emojiButtonSize: 30,
      //   emojiSize: 20,
      //   previewPosition: "none",
      //   onEmojiSelect: function (emoji) {
          
      //     // Insert the emoji at the cursor position
      //     insertText(this.el, emoji.native + " ")
      //   },
      //   data: async () => {
      //     const response = await fetch(
      //       "https://cdn.jsdelivr.net/npm/@emoji-mart/data",
      //     );
  
      //     return response.json()
      //   },
      // });
      // console.log(picker)
      // this.el.querySelector("#picker").appendChild(picker);
    
    },
    updated() {
      console.log("updated");
      const picker = new Picker({
        emojiButtonSize: 30,
        emojiSize: 20,
        previewPosition: "none",
        onEmojiSelect: function (emoji) {
          
          // Insert the emoji at the cursor position
          const area = document.querySelector("#editor");
          insertText(area, emoji.native + " ")
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

}

export { EmojiHooks }