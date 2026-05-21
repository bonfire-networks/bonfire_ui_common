// Lazily-loaded media-player bundle. Kept OUT of the main LiveView bundle
// (bonfire_live.js) and fetched on demand by remote_media_live.hooks.js the
// first time a media player actually mounts — so pages without media don't pay
// for vidstack + hls.js (~280KB gzip). Built as a standalone ESM module
// (`build.vidstack`/`watch.vidstack` in package.json).
export { VidstackPlayer, VidstackPlayerLayout } from "vidstack/global/player";
export { default as HLS } from "hls.js";
