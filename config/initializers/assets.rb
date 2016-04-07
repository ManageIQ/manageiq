Rails.application.config.assets.precompile += %w(
  jquery-1.8/jquery.js jquery_overrides.js jquery
  novnc-rails noVNC/web-socket-js/WebSocketMain.swf
  spice-html5-bower spice-html5-bower/spiceHTML5/spicearraybuffer.js
  codemirror/modes/*.js codemirror/themes/*.css
)
