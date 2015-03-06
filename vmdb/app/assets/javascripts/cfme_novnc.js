"use strict";
var rfb;

function sendCtrlAltDel() {
  rfb.sendCtrlAltDel();
  return false;
}

function updateState(rfb, state, oldstate, msg) {
  var level;
  var s   = $D('noVNC_status');
  var sb  = $D('noVNC_status');
  var cad = $D('sendCtrlAltDelButton');
  switch (state) {
    case 'failed':       level = "danger";  break;
    case 'fatal':        level = "danger";  break;
    case 'normal':       level = "success"; break;
    case 'disconnected': level = "default"; break;
    case 'loaded':       level = "success"; break;
    default:             level = "warning"; break;
  }

  cad.disabled = state !== "normal";

  if (typeof(msg) !== 'undefined') {
    sb.setAttribute("class", "label label-" + level);
    s.innerHTML = msg;
  }
}

$(function() {
  $D('sendCtrlAltDelButton').style.display = "inline"; // FIXME
  $D('sendCtrlAltDelButton').onclick = sendCtrlAltDel;

  var host     = window.location.hostname;
  var vnc_el   = $('#vnc');
  var port     = vnc_el.attr('data-port');
  var password = vnc_el.attr('data-password');
  var encrypt  = vnc_el.attr('data-encrypt') !== undefined;
  var path = "";
  rfb = new RFB({'target': $D('noVNC_canvas'),
    'encrypt':      encrypt,
    'true_color':   true,
    'local_cursor': true,
    'shared':       true,
    'view_only':    false,
    'updateState':  updateState});
  rfb.connect(host, port, password, path);
  console.log("host: "     + host);
  console.log("port: "     + port);
  console.log("password: " + password);
  console.log("encrypt: "  + encrypt);
  console.log("path: "     + path);
});
