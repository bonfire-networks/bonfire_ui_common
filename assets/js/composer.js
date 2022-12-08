import insertText from 'insert-text-at-cursor';
import getCaretCoordinates from 'textarea-caret';



let ComposerHooks = {};

ComposerHooks.Composer = {

    mounted() {
      const MIN_PREFIX_LENGTH = 2
      // Technically mastodon accounts allow dots, but it would be weird to do an autosuggest search if it ends with a dot.
      // Also this is rare. https://github.com/tootsuite/mastodon/pull/6844
      const VALID_CHARS = '[\\w\\+_\\-:]'
      const MENTION_PREFIX = '(?:@)'
      const HASH_PREFIX = '(?:#)'
      const MENTION_REGEX = new RegExp(`(?:\\s|^)(${MENTION_PREFIX}${VALID_CHARS}{${MIN_PREFIX_LENGTH},})$`)
      const HASH_REGEX = new RegExp(`(?:\\s|^)(${HASH_PREFIX}${VALID_CHARS}{${MIN_PREFIX_LENGTH},})$`)

      const textarea = this.el.querySelector("textarea")
      const suggestions_menu = this.el.querySelector(".menu")



        
      suggestions_menu.addEventListener("click", (e) => {
        // get the data-id attribute from the button child element
        const id = e.target.closest('button').dataset.id
        const inputText = e.target.closest('button').dataset.input
        
        // Remove the previous text from the current cursor position untill a space is found
        const text = textarea.value
        const pos = textarea.selectionStart
        const before = text.substring(0, pos)
        const beforeSpace = before.lastIndexOf(' ')
        const beforeText = before.substring(0, beforeSpace)
        textarea.value = beforeText + ' '
        // Insert the id of the selected user


        insertText(textarea, id + " ")
        textarea.focus()         
      })

      textarea.addEventListener("input", () => {
        // Get the input text from the textarea
        const inputText = textarea.value;

        // Get the mentions from the input text, only if the character is followed by a word character and not an empty space
        const mentions = inputText.match(MENTION_REGEX)
        const hashtags = inputText.match(HASH_REGEX)
      
        let list = ''
        const menu = this.el.querySelector('.menu')
        if(mentions) {
          const text = mentions[0].split('@').pop()
          getFeedItems(text, '@').then(res => {
          // if suggestions is greater than 0 append below textarea a menu with the suggestions
            if (res.length > 0) {
              menu.classList.remove("hidden", false)
              
              var caret = getCaretCoordinates(textarea, textarea.selectionEnd);
              menu.style.top = caret.top + caret.height + 'px'
              menu.style.left = caret.left + 'px'

              res.forEach((item) => {
                list += mentionItemRenderer(item, text)
              })
            } else {
              menu.classList.add("hidden", false)
              list +=  ` `
            }
            menu.innerHTML = list
          })
          
        // } else if (hashtags) {
        //   const text = hashtags[0].split('#').pop()
        //   getFeedItems(text, '#').then(res => {
        //     // if suggestions is greater than 0 append below textarea a menu with the suggestions
        //       if (res.length > 0) {
        //         console.log(res.length)
        //         res.forEach((item) => {
        //           list += hashtagItemRenderer(item)
        //         })
        //       } else {
        //         list +=  ` `
        //       }
        //       menu.innerHTML = list
        //     })
        // 
          }  else {
          // no suggestions
          list +=  ` `
          menu.innerHTML = list
          menu.classList.add("hidden", false)
        }
    })
  }
}

const mentionItemRenderer = (item, text) => {
  return `
    <li class="flex rounded flex-col py-1">
      <button class="gap-1 rounded py-1.5" type="button" data-id="${item.id}" data-input="${text}">
        <div class="text-sm text-neutral-content font-semibold">${item.value}</div>
        <div class="text-xs text-neutral-content/70 font-regular">${item.id}</div>
      </button>
    </li>`
}

// const hashtagItemRenderer = (item) => {
//   return `
//     <li class="flex rounded flex-col py-1">
//       <button>
//         <div class="text-sm text-neutral-content font-semibold">#${item.value}</div>
//       </button>
//     </li>`
// }



function getFeedItems(queryText, prefix) {
  // console.log(prefix)
  if (queryText && queryText.length > 0) {
    return new Promise((resolve) => {
      // this requires the bonfire_tag extension
      fetch("/api/tag/autocomplete/ck5/" + prefix + "/" + queryText)
        .then((response) => response.json())
        .then((data) => {
          let values = data.map((item) => ({
            id: item.id,
            value: item.name,
            link: item.link,
          }));
          resolve(values);
        })
        .catch((error) => {
          console.error("There has been a problem with the tag search:", error);
          resolve([]);
        });
    });
  } else return [];
}

export { ComposerHooks }