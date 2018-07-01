// JavaScript Document
ipfs_gateway_self='__IPFS_GATEWAY_SELF__';  // IPFS gateway of this node
ipfs_gateway_origin='__IPFS_GATEWAY_ORIGIN__';  // IPFS gateway of origin stream
m3u8_ipfs='__IPFS_GATEWAY_ORIGIN__/ipns/__IPFS_ID_ORIGIN__';  // URL to m3u8 over IPFS gateway
m3u8_http_urls=[__M3U8_HTTP_URLS__];  // Optional list of URLs to m3u8 over HTTP

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