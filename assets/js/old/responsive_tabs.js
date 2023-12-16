
let ResponsiveTabsHooks = {};

ResponsiveTabsHooks.ResponsiveTabsHook = {
  mounted() {

    const container = this.el
    const primary = container.querySelector('.tabs-list')
    const primaryItems = container.querySelectorAll('.tabs-list > li:not(.-more)')

    // insert "more" button and duplicate the list

    primary.insertAdjacentHTML('beforeend', `
    <li class="-more flex-grow">
      <div class="dropdown dropdown-end block leading-[3rem] !px-0.5 !h-[3rem]">
        <label tabindex="0" class="more-btn btn btn-sm btn-circle btn-ghost">
        <svg xmlns="http://www.w3.org/2000/svg" width="1em" height="1em" preserveAspectRatio="xMidYMid meet" viewBox="0 0 24 24"><g fill="none"><path d="M24 0v24H0V0h24ZM12.593 23.258l-.011.002l-.071.035l-.02.004l-.014-.004l-.071-.035c-.01-.004-.019-.001-.024.005l-.004.01l-.017.428l.005.02l.01.013l.104.074l.015.004l.012-.004l.104-.074l.012-.016l.004-.017l-.017-.427c-.002-.01-.009-.017-.017-.018Zm.265-.113l-.013.002l-.185.093l-.01.01l-.003.011l.018.43l.005.012l.008.007l.201.093c.012.004.023 0 .029-.008l.004-.014l-.034-.614c-.003-.012-.01-.02-.02-.022Zm-.715.002a.023.023 0 0 0-.027.006l-.006.014l-.034.614c0 .012.007.02.017.024l.015-.002l.201-.093l.01-.008l.004-.011l.017-.43l-.003-.012l-.01-.01l-.184-.092Z"/><path fill="currentColor" d="M5 10a2 2 0 1 1 0 4a2 2 0 0 1 0-4Zm7 0a2 2 0 1 1 0 4a2 2 0 0 1 0-4Zm7 0a2 2 0 1 1 0 4a2 2 0 0 1 0-4Z"/></g></svg>
        </label>
        <ul tabindex="0" class="-secondary p-2 shadow !block dropdown-content menu bg-base-100 rounded-box w-52">
          ${primary.innerHTML}
        </ul>
      </div>
    </li>

  `)

    const secondary = container.querySelector('.-secondary')
    console.log(secondary)
    const secondaryItems = secondary.querySelectorAll('li')
    const allItems = container.querySelectorAll('li')
    const moreLi = primary.querySelector('.-more')
    const moreBtn = moreLi.querySelector('.more-btn')
    moreBtn.addEventListener('click', (e) => {
      e.preventDefault()
      container.classList.toggle('--show-secondary')
      moreBtn.setAttribute('aria-expanded', container.classList.contains('--show-secondary'))
    })

    // adapt tabs

    const doAdapt = () => {
      // reveal all items for the calculation
      allItems.forEach((item) => {
        item.classList.remove('hidden')
      })

      // hide items that won't fit in the Primary
      let stopWidth = moreBtn.offsetWidth
      console.log("resizing")
      console.log(stopWidth)

      let hiddenItems = []
      const primaryWidth = primary.offsetWidth
      console.log(primaryWidth)
      primaryItems.forEach((item, i) => {
        if (primaryWidth >= stopWidth + item.offsetWidth + 80) {
          console.log("test")
          console.log(stopWidth + item.offsetWidth)
          stopWidth += item.offsetWidth
        } else {
          item.classList.add('hidden')
          hiddenItems.push(i)
        }
      })

      // toggle the visibility of More button and items in Secondary
      if (!hiddenItems.length) {
        moreLi.classList.add('hidden')
        container.classList.remove('--show-secondary')
        moreBtn.setAttribute('aria-expanded', false)
      }
      else {
        secondaryItems.forEach((item, i) => {
          if (!hiddenItems.includes(i)) {
            item.classList.add('hidden')
          }
        })
      }
    }

    doAdapt() // adapt immediately on load
    window.addEventListener('resize', doAdapt) // adapt on window resize

  }
}


export { ResponsiveTabsHooks }
