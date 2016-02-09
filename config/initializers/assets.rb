Rails.application.config.assets.precompile += %w(
  jquery-1.8/jquery.js jquery_overrides.js
  miq_novnc.js
  spice-html5.js spiceHTML5/spicearraybuffer.js
  codemirror/modes/*.js codemirror/themes/*.css
)
