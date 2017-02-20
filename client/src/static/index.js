var styles = require('../app/main.css');

var Elm = require('../app/Main.elm');
var mountNode = document.getElementById('app');
var app = Elm.Main.embed(mountNode, {
  buildVersion: BUILD_VERSION,
  buildTime: BUILD_TIME,
  buildTier: BUILD_TIER,
  apiHost: API_HOST
});
