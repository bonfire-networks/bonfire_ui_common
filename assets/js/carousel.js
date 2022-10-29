import Splide from '@splidejs/splide';
import '@splidejs/splide/css';

let CarouselHooks = {};

CarouselHooks.CarouselHook = {
  mounted() {
    new Splide('.splide', {
      perPage: 1,
      gap: '1rem',
      width: '100%',
      breakpoints: {
        640: {
            perPage: 1,
        },
      },
    }).mount()
  }
}


export { CarouselHooks } 