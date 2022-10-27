import Splide from '@splidejs/splide';
import '@splidejs/splide/css';

let CarouselHooks = {};

CarouselHooks.CarouselHook = {
  mounted() {
    new Splide('.splide', {
      perPage: 2,
      gap: '1rem',
      breakpoints: {
        640: {
            perPage: 1,
        },
      },
    }).mount()
  }
}


export { CarouselHooks } 