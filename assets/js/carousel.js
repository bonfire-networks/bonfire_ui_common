import Glider from 'glider-js';
import '../node_modules/glider-js/glider.min.css';

let CarouselHooks = {};

CarouselHooks.CarouselHook = {
  mounted() {
    new Glider(document.querySelector('.carousel'), {
      slidesToShow: 3,
      slidesToScroll: 1,
      draggable: true,
      dots: '.dots',
      arrows: {
        prev: '.glider-prev',
        next: '.glider-next'
      }
    });
    // new Splide('.splide', {
    //   perPage: 2,
    //   gap: '1rem',
    //   width: '100%',
    //   breakpoints: {
    //     640: {
    //         perPage: 1,
    //     },
    //   },
    // }).mount()
  }
}


export { CarouselHooks } 