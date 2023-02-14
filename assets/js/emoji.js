let EmojiHooks = {};

const { Picker } = await import('emoji-mart')
import insertText from 'insert-text-at-cursor';
const promise = import('@emoji-mart/data/sets/14/twitter.json').then(r => r.default)




EmojiHooks.EmojiPicker = {
  
  mounted() {
    const picker = new Picker({
      data: () => promise,
      emojiButtonSize: 30,
      emojiSize: 20,
      set: "twitter",
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
    // wait for the data to be loaded correctly before appending the picker
    this.el.querySelector("#picker").appendChild(picker);

    
    }
}

export { EmojiHooks }