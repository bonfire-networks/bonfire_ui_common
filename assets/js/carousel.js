import Glider from 'glider-js';

let CarouselHooks = {};

CarouselHooks.CarouselHook = {
  mounted() {
    console.log("glider")
    new Glider(document.querySelector('.glider'), {
      slidesToShow: 1,
      dots: '#dots',
      draggable: true,
      arrows: {
        prev: '.glider-prev',
        next: '.glider-next'
      }
    });
  }
}


export { CarouselHooks } 