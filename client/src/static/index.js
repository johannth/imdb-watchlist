var styles = require('../app/main.css')

var Elm = require('../app/Main.elm');
var mountNode = document.getElementById('app');
var app = Elm.Main.embed(mountNode, {
  build_version: BUILD_VERSION,
  build_time: BUILD_TIME,
  build_tier: BUILD_TIER
});
