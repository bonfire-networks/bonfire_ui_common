import Glider from 'glider-js';

let CarouselHooks = {};

CarouselHooks.CarouselHook = {
  mounted() {
    const glider = document.querySelector('.glider')
    console.log(glider)
    new Glider(document.querySelector('.glider'), {
      // Mobile-first defaults
      slidesToShow: 3,
      draggable: true,
      slidesToScroll: 1,
      dots: '.dots'
    });
  }
}


export { CarouselHooks } 