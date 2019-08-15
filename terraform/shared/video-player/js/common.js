// IPFS config
var ipfs_gateway_self = '__IPFS_GATEWAY_SELF__';     // IPFS gateway of this node
var ipfs_gateway_origin = '__IPFS_GATEWAY_ORIGIN__'; // IPFS gateway of origin stream

// Live stream config
var m3u8_ipfs = 'live.m3u8';                                          // HTTP or local path to m3u8 file containing IPFS content
// var m3u8_ipfs = '__IPFS_GATEWAY_ORIGIN__/ipns/__IPFS_ID_ORIGIN__'; // IPNS path to m3u8 file containing IPFS content (uncomment to enable)
var m3u8_http_urls = [__M3U8_HTTP_URLS__];                            // HTTP or local paths to m3u8 file containing HTTP content (optional)

// Configure default playback behaviour
var stream_type = 'application/x-mpegURL'; // Type of video stream
var stream_url_ipfs = m3u8_ipfs;           // Source of IPFS video stream
var stream_urls_http = m3u8_http_urls;     // Source of HTTP video stream

// Process URL params
function getURLParam(key) {
  return new URLSearchParams(window.location.search).get(key);
}

var ipfs_gw = getURLParam('gw')     // Set IPFS gateway URL to override playback gateway
var live_ipfs = getURLParam('live') // Set m3u8 file URL to override IPFS live stream
var vod_ipfs = getURLParam('vod')   // Set IPFS content hash of mp4 file to play IPFS on-demand video stream
var startFrom = getURLParam("startFrom"); // Timecode to start video playing from

if (ipfs_gw) {
  ipfs_gateway_self = ipfs_gw;
}

if (live_ipfs) {
  stream_type = 'application/x-mpegURL';
  stream_url_ipfs = live_ipfs;
  stream_urls_http = m3u8_http_urls;
}

if (vod_ipfs) {
  stream_type = 'video/mp4';
  stream_url_ipfs = ipfs_gateway_self + '/ipfs/' + vod_ipfs;
  stream_urls_http = [];

  document.getElementById('selectingTitle').innerHTML = 'Select Recorded Stream Source';
}

// Configure video player
var live = videojs('live', { liveui: true });

// For any browser except Safari
//if (/^((?!chrome|android).)*safari/i.test(navigator.userAgent) === false) {
// Override native player for platform and browser consistency
videojs.options.html5.nativeAudioTracks = false;
videojs.options.html5.nativeVideoTracks = false;
videojs.options.hls.overrideNative = true;
//}

function httpStream() {
  live.src({
    src: stream_urls_http[Math.floor(Math.random() * m3u8_http_urls.length)],
    type: stream_type
  });
  loadStream();
}

//Video stage counter
var streamState = 0;

function ipfsStream() {
  live.src({
    src: stream_url_ipfs,
    type: stream_type
  });
  loadStream();
  videojs.Hls.xhr.beforeRequest = function(options) {

    //First hit is m3u8, start playing
    if (options.uri.indexOf('.m3u8') > 0) {
      if (!streamState) {
        live.play();
        streamState = 1;
      }
    }

    if (options.uri.indexOf('/ipfs/') > 0) {
      document.getElementById('loadingTitle').innerHTML = 'Located stream via IPFS';
      document.getElementById('msg').innerHTML = 'Downloading video content...';
      // Replace IPFS gateway of origin with that of this node
      options.uri = ipfs_gateway_origin + options.uri.substring(options.uri.indexOf('/ipfs/'));
      // Do seek counter

      if (streamState < 3) {
        streamState++;
        if (streamState == 3) {
          if (!startFrom) {
            setTimeout(function() { live.liveTracker.seekToLiveEdge(); }, 1);
          } else {
            setTimeout(function() { live.currentTime(startFrom); }, 1);
          }
        }
      }
    }

    if (options.uri.indexOf('/ipns/') > 0) {
      document.getElementById('loadingTitle').innerHTML = 'Located stream via IPFS';
      document.getElementById('msg').innerHTML = 'Downloading video content...';
      options.uri = ipfs_gateway_origin + options.uri.substring(options.uri.indexOf('/ipns/'));
    }
    console.debug(options.uri);
    return options;
  };
}

function loadStream() {
  document.getElementById('loadingStream').style.display = 'block';
  document.getElementById('selectStream').style.display = 'none';
}

document.querySelector('.ipfs-stream').addEventListener('click', function(event) {
  ipfsStream();
});

document.querySelector('.http-stream').addEventListener('click', function(event) {
  httpStream();
});

live.metadata = 'none';

live.on('loadedmetadata', function() {
  document.getElementById('streamSelector').style.display = 'none';
});

live.on('loadeddata', function(event) {
  console.debug(event);
});

var refreshButton = document.createElement('button');
refreshButton.className = 'button button-primary compact stream-refresh';
refreshButton.innerHTML = 'Refresh Page and Try Again';
refreshButton.addEventListener('click', function() {
  window.location.reload(true);
});

live.on('error', function(event) {
  console.debug(this.error());
  document.getElementById('loadingTitle').innerHTML = 'Unable to load video stream';
  document.querySelector('.loader-animation').style.display = 'none';
  document.getElementById('msg').innerHTML = this.error().message;
  document.getElementById('loadingStream').appendChild(refreshButton);
});

if (!stream_urls_http || !Array.isArray(stream_urls_http) || (stream_urls_http.length === 0)) {
  document.querySelector('.http-stream').setAttribute('disabled', 'disabled');
}
