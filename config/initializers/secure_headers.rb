if defined?(SecureHeaders)
  SecureHeaders::Configuration.default do |config|
    config.hsts = "max-age=#{20.years.to_i}"
    config.x_frame_options = 'SAMEORIGIN'
    config.x_content_type_options = "nosniff"
    config.x_xss_protection = "1; mode=block"
    # Need google fonts in fonts_src for https://fonts.googleapis.com/css?family=IBM+Plex+Sans+Condensed%7CIBM+Plex+Sans:400,600&display=swap (For carbon-charts download)
    config.csp = {
      :report_only => false,
      :default_src => ["'self'"],
      :frame_src   => ["'self'"],
      :font_src    => ["'self'", 'https://fonts.gstatic.com', "https://fonts.googleapis.com"],
      :img_src     => ["'self'", "data:"],
      :connect_src => ["'self'"],
      :style_src   => ["'unsafe-inline'", "'self'", "https://fonts.googleapis.com", "https://fonts.gstatic.com"],
      :script_src  => ["'unsafe-eval'", "'unsafe-inline'", "'self'"],
      :report_uri  => ["/dashboard/csp_report"]
    }
  end
end
