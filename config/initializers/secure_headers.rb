SecureHeaders::Configuration.default do |config|
  config.hsts = "max-age=#{20.years.to_i}",
  config.x_frame_options = 'SAMEORIGIN'
  config.x_content_type_options = "nosniff"
  config.x_xss_protection = "1; mode=block"
  config.csp = {
    :enforce     => true,
    :default_src => ["'self'"],
    :frame_src   => ["'self'"],
    :connect_src => ["'self'"],
    :style_src   => ["'unsafe-inline'", "'self'"],
    :script_src  => ["'unsafe-eval'", "'unsafe-inline'", "'self'"],
    :report_uri  => ["/dashboard/csp_report"]
  }
end
