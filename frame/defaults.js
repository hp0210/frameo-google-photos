// AlbumFrame default settings. Saved settings (config.json, via /cgi-bin/ctl?a=getcfg) override these.
window.DEFAULTS = {
  albums: [],                 // Google Photos shared-album links
  refreshMin: 30,             // how often to re-read the albums (minutes)
  intervalSec: 20,            // how long each photo stays on screen
  shuffle: true,
  showVideos: true,           // false = skip videos entirely
  kenburns: true,             // slow zoom-in / drift effect
  fill: true,                 // crop edges a little so most photos fill the screen
  pairPortraits: true,        // two portrait photos side by side
  transitionSec: 1.5,         // cross-fade length
  photoDate: true,            // "taken on" label
  camera: 'off',              // camera from the photo's EXIF under the date: 'off' | 'camera' | 'focal' (+ focal length) | 'lens' (+ full lens)
  clock: true,
  clock24: false,
  weather: { on: true, name: '', lat: null, lon: null, tz: 'auto', unit: 'c' },   // pick the location in Frame settings
  night: { on: false, from: '22:00', to: '07:00' },  // dim to black during these hours (tap wakes for 5 min)
  remote: false               // allow editing these settings from a phone/computer on the home network
};
window.mergeCfg = function (d, s) {
  var o = {}, k;
  for (k in d) o[k] = d[k];
  for (k in (s || {})) {
    if (d[k] && typeof d[k] === 'object' && !Array.isArray(d[k])) o[k] = window.mergeCfg(d[k], s[k]);
    else o[k] = s[k];
  }
  return o;
};
window.loadCfg = function (cb) {
  var x = new XMLHttpRequest();
  x.open('GET', '/cgi-bin/ctl?a=getcfg&t=' + Date.now());
  x.onload = function () { var s = {}; try { s = JSON.parse(x.responseText); } catch (e) {} cb(window.mergeCfg(window.DEFAULTS, s)); };
  x.onerror = function () { cb(window.mergeCfg(window.DEFAULTS, {})); };
  x.send();
};
