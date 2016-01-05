Rails.application.config.assets.precompile += %w(
  miq_browser_detect.js
  jquery-1.8/jquery.js jquery_overrides.js
  miq_policy/import.js
  novnc-rails.js miq_novnc.js
  spice-html5.js

  xml_display.css
  container_topology.css service_dialogs.css import_policy.css vmrc.css
)
