// IPFS config
var ipfs_gateway = '__IPFS_GATEWAY__'; // IPFS gateway

// Live stream config
var m3u8_ipfs = 'live.m3u8';                                          // HTTP or local path to m3u8 file containing IPFS content
//m3u8_ipfs = '__IPFS_GATEWAY__/ipns/__IPFS_ID_ORIGIN__';               // IPNS path to m3u8 file containing IPFS content (uncomment to enable)
var m3u8_http_urls = [__M3U8_HTTP_URLS__];                            // HTTP or local paths to m3u8 file containing HTTP content (optional)

// Video sharing links config 
var date = new Date().toLocaleDateString("en-CA", {timeZone: "America/Toronto"}); // Current date (default to American/Toronto)
var rootURL = window.location.href.split('?')[0];                                 // Root URL used in sharing links

// Process URL params
function getURLParam(key) {
  return new URLSearchParams(window.location.search).get(key);
}

var ipfs_gw = getURLParam('gw');                          // Set custom IPFS gateway
if (getURLParam('m3u8'))
  var m3u8_ipfs = getURLParam('m3u8');                    // Set m3u8 file URL to override IPFS live stream
var vod_ipfs = getURLParam('vod') || getURLParam('ipfs'); // Set IPFS content hash of mp4 file to play IPFS on-demand video stream ('ipfs' for backward compatability)
var start_from = getURLParam("from");                     // Set IPFS content hash or timecode to start video playback from

// Configure default playback behaviour
var stream_type = 'application/x-mpegURL'; // Type of video stream
var stream_url_ipfs = m3u8_ipfs;           // Source of IPFS video stream
var stream_urls_http = m3u8_http_urls;     // Source of HTTP video stream

if (ipfs_gw) {
  ipfs_gateway = ipfs_gw;
}

if (vod_ipfs) {
  stream_type = 'video/mp4';
  stream_url_ipfs = ipfs_gateway + '/ipfs/' + vod_ipfs;
  stream_urls_http = [];
  document.getElementById('selectingTitle').innerHTML = 'Select recorded stream source';
}

// If start_from is not a number it's probably an IPFS hash so calculate to correct start_from
var hash="";
if (start_from && +start_from != start_from) {
  hash = start_from;
  // Remove start_from value since the hash may not be in the list
  start_from = undefined;
  var xmlhttp = new XMLHttpRequest();
  xmlhttp.onreadystatechange = function () {
    if (this.readyState == 4 && this.status == 200) {
      file = this.response;
      fileline = file.split("\n");
      counter = 0;
      // Loop through entries in the file
      for (var a = 0; a < fileline.length; a++) {
        // Look for EXTINF tags that describe the length of the chunk
        if (fileline[a].indexOf("EXTINF:") > 0) {
          // Parse out the length of the chunk
          var number = fileline[a].substring(fileline[a].indexOf("EXTINF:") + 7);
          number = number.substring(0, number.length - 1);
          // Skip over chunk hash information
          a++;
          if (fileline[a].indexOf(hash) > 0) {
            // If hash is found set the start_from to the counter and exit;
            start_from = counter;
            return;
          }
          // Add chunk length to counter
          counter = counter + parseFloat(number);
        }
      }
    }
  };
  xmlhttp.open("GET", m3u8_ipfs, true);
  xmlhttp.send();
}

// Function to get hash from timeindex
function getHashFromTime(timeindex) {
  var xmlhttp = new XMLHttpRequest();
  xmlhttp.open("GET", m3u8_ipfs, false);
  xmlhttp.send();
  if (xmlhttp.readyState == 4 && xmlhttp.status == 200) {
    file = xmlhttp.response;
    fileline = file.split("\n");
    counter = 0;
    hash = "";
    // Loop through entries in the file
    for (var a = 0; a < fileline.length; a++) {
      // Look for EXTINF tags that describe the length of the chunk
      if (fileline[a].indexOf("EXTINF:") > 0) {
        // Parse out the length of the chunk
        var number = fileline[a].substring(fileline[a].indexOf("EXTINF:") + 7);
        number = number.substring(0, number.length - 1);
        counter = counter + parseFloat(number);

        // Parse out current hash
        var hash = fileline[a+1].substring(fileline[a+1].lastIndexOf("/") + 1);

        // Check if the current counter is larger than timeindex requested
        if (counter > timeindex) return hash;

        // Skip over chunk hash information
        a++;
      }
    }
  }
  return "";
}

// Configure video player
var live = videojs('live', { liveui: true });

// Override native player for platform and browser consistency
videojs.options.html5.nativeAudioTracks = false;
videojs.options.html5.nativeVideoTracks = false;
videojs.options.hls.overrideNative = true;

function httpStream() {
  live.src({
    src: stream_urls_http[Math.floor(Math.random() * m3u8_http_urls.length)],
    type: stream_type
  });
  loadStream();
}

// Counter to track video playback state
var streamState = 0;

function ipfsStream() {
  live.src({
    src: stream_url_ipfs,
    type: stream_type
  });
  loadStream();

  // Start playback from timecode if exists
  if (vod_ipfs && start_from && +start_from == start_from) {
    setTimeout(function() {
      live.currentTime(start_from);
    }, 1);
  }

  videojs.Hls.xhr.beforeRequest = function(options) {

    // When .m3u8 is loaded, start playback and transition to streamState = 1
    if (options.uri.indexOf('.m3u8') > 0) {
      if (!streamState) {
        live.play();
        streamState = 1;
      }
    }

    if (options.uri.indexOf('/ipfs/') > 0) {
      document.getElementById('loadingTitle').innerHTML = 'Located stream via IPFS';
      document.getElementById('msg').innerHTML = 'Downloading video content...';
      // Use specified IPFS gateway by replacing it in the uri
      options.uri = ipfs_gateway + options.uri.substring(options.uri.indexOf('/ipfs/'));

      // Wait for two .ts chunks to be loaded before applying seek action
      if (streamState < 3) {
        streamState++;
        if (streamState == 3) {
          if (!start_from) {
            // Seek to live after waiting 1 s
            setTimeout(function() { live.liveTracker.seekToLiveEdge(); }, 1);
          } else {
            // Seek to start_from time after waiting 1 s
            setTimeout(function() { live.currentTime(start_from); }, 1);
          }
        }
      }
    }

    if (options.uri.indexOf('/ipns/') > 0) {
      document.getElementById('loadingTitle').innerHTML = 'Located stream via IPFS';
      document.getElementById('msg').innerHTML = 'Downloading video content...';
      options.uri = ipfs_gateway + options.uri.substring(options.uri.indexOf('/ipns/'));
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
refreshButton.innerHTML = 'Refresh page and try again';
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

// Video sharing links
function getShareLink(key) {
  if (vod_ipfs) {
    return `${rootURL}?vod=${vod_ipfs}&from=${live.currentTime()}`;
  }
  var m3u8 = getURLParam('m3u8');
  if (!m3u8) {
    m3u8 = `live-${date}.m3u8`;
  }
  var bookmark = getHashFromTime(live.currentTime());
  return `${rootURL}?m3u8=${m3u8}&from=${bookmark}`;
}

setInterval(function () {
  var link = document.getElementById('link');
  link.value = getShareLink();
}, 5000);

var shareTweet = document.querySelector('.share-tweet');
var shareLink = document.querySelector('.share-link');

if (shareTweet) {
  shareTweet.addEventListener('click', function() {
    var link = document.getElementById('link');
    link.value = getShareLink();
    const tweetURL = link.value;
    window.open(`https://twitter.com/intent/tweet?url=${encodeURIComponent(tweetURL)}`);
  });
}

if (shareLink) {
  shareLink.addEventListener('click', function() {
    var link = document.getElementById('link');
    link.value = getShareLink();
    link.select();
    link.setSelectionRange(0, 99999); // For mobile devices
    document.execCommand('copy');
    alert('Link copied to clipboard');
  });
}
