// JavaScript Document
var ipfs_gateway_self='__IPFS_GATEWAY_SELF__';  // IPFS gateway of this node
var ipfs_gateway_origin='__IPFS_GATEWAY_ORIGIN__';  // IPFS gateway of origin stream
var m3u8_ipfs='live.m3u8';  // File path to m3u8 with IPFS content via HTTP server
// var m3u8_ipfs='__IPFS_GATEWAY_ORIGIN__/ipns/__IPFS_ID_ORIGIN__';  // URL to m3u8 via IPNS (uncomment to enable)
var m3u8_http_urls=[__M3U8_HTTP_URLS__];  // Optional list of URLs to m3u8 over HTTP

function getQueryVariable(variable) {
  var query = window.location.search.substring(1);
  var vars = query.split('&');
  for (var i = 0; i < vars.length; i++) {
    var pair = vars[i].split('=');
    if (decodeURIComponent(pair[0]) == variable) {
      return decodeURIComponent(pair[1]);
    }
  }
  console.log('Query variable %s not found', variable);
}

if (getQueryVariable("url")) {
  m3u8_ipfs = getQueryVariable("url");
}

if (getQueryVariable("ipfs_gateway_self")) {
  ipfs_gateway_self = getQueryVariable("ipfs_gateway_self");
}

var live = videojs('live');

// For any browser except Safari
if (/^((?!chrome|android).)*safari/i.test(navigator.userAgent) == false) {
  // Override native player for platform and browser consistency
  videojs.options.html5.nativeAudioTracks = false;
  videojs.options.html5.nativeVideoTracks = false;
  videojs.options.hls.overrideNative = true;
}

function httpStream() {
  live.src({
    src: m3u8_http_urls[Math.floor(Math.random() * m3u8_http_urls.length)],
    type: 'application/x-mpegURL',
  });
  loadStream();
}

function ipfsStream() {
  live.src({
    src: m3u8_ipfs,
    type: 'application/x-mpegURL',
  });
  loadStream();
  videojs.Hls.xhr.beforeRequest = function(options) {
    // Replace IPFS gateway of origin with that of this node
    options.uri = options.uri.replace(ipfs_gateway_origin, ipfs_gateway_self);
    if (options.uri.indexOf("/ipfs/")) {
      document.getElementById("loadingTitle").innerHTML = "Located stream via IPFS"
      document.getElementById("msg").innerHTML = "Downloading video content..."
    }
    console.debug(options.uri);
    return options;
  };
}

function loadStream() {
  document.getElementById("LoadingStream").style.display = "block";
  document.getElementById("SelectStream").style.display = "none";
}

document.querySelector('.ipfs-stream').addEventListener('click', function(event){
  ipfsStream();
});

document.querySelector('.http-stream').addEventListener('click', function(event){
  httpStream();
});

live.metadata="none";

live.on('loadedmetadata', function() {
  document.getElementById("StreamSelector").style.display = "none";
});

live.on('loadeddata', function(event) {
  console.debug(event);
});

live.on('error', function(event) {
  console.debug(this.error());
  document.getElementById('loadingTitle').innerHTML = 'Unable to load live stream'
  document.querySelector('.loader-animation').style.display = 'none';
  document.getElementById('msg').innerHTML = this.error().message;
});

if (!m3u8_http_urls || !Array.isArray(m3u8_http_urls) || (m3u8_http_urls.length == 0)) {
  document.querySelector('.http-stream').setAttribute('disabled', 'disabled');
}