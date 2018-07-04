// JavaScript Document
var ipfs_gateway_self='http://ipfs-server.mesh.world:8080';  // IPFS gateway of this node
var ipfs_gateway_origin='http://ipfs-server.mesh.world:8080';  // IPFS gateway of origin stream
var m3u8_ipfs='live.m3u8';  // File path to m3u8 with IPFS content via HTTP server
// var m3u8_ipfs='http://ipfs-server.mesh.world:8080/ipns/QmfF1FG9mfPPnapxUxooFX2VdZBHzRKcHMTDAQBwc2DSf8';  // URL to m3u8 via IPNS (uncomment to enable)
var m3u8_http_urls=[];  // Optional list of URLs to m3u8 over HTTP

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
      document.getElementById("loadingTitle").innerHTML="Located stream via IPNS"
      document.getElementById("msg").innerHTML="Downloading video content..."
    }
    console.debug(options.uri);
    return options;
  };
}

function loadStream() {
  document.getElementById("LoadingStream").style.display = "block";
  document.getElementById("SelectStream").style.display="none";
}

document.querySelector('.stream-option').addEventListener('click', function(event){
  if (event.currentTarget.classList.contains('ipfs-stream')) {
    ipfsStream();
  } else {
    httpStream();
  }
});

live.metadata="none";

live.on('loadedmetadata', function() {
  document.getElementById("StreamSelecter").style.display = "none";
});

live.on('loadeddata', function(event) {
  console.debug(event);
});

live.on('error', function(event) {
  console.debug(this.error());
  document.getElementById("msg").innerHTML=this.error().message;
});

if (!m3u8_http_urls || !Array.isArray(m3u8_http_urls) || (m3u8_http_urls.length==0)) {
  document.getElementById("clearStream").style.display="none";
}