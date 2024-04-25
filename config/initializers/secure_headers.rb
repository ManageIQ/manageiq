if defined?(SecureHeaders)
  # Please make sure these values are properly reflected in apache config:
  # - https://github.com/ManageIQ/manageiq-appliance/blob/master/COPY/etc/httpd/conf.d/manageiq-https-application.conf
  # - https://github.com/ManageIQ/manageiq-pods/blob/master/manageiq-operator/pkg/helpers/miq-components/httpd_conf.go
  SecureHeaders::Configuration.default do |config|
    config.hsts = "max-age=#{20.years.to_i}"
    # X-Frame-Options
    config.x_frame_options = 'SAMEORIGIN'
    # X-Content-Type-Options
    config.x_content_type_options = "nosniff"
    # X-XSS-Protection
    # X-Permitted-Cross-Domain-Policies
    config.x_xss_protection = "1; mode=block"
    config.referrer_policy = "no-referrer-when-downgrade"
    # Content-Security-Policy
    # Need google fonts in fonts_src for https://fonts.googleapis.com/css?family=IBM+Plex+Sans+Condensed%7CIBM+Plex+Sans:400,600&display=swap (For carbon-charts download)
    config.csp = {
      :report_only => false,
      :report_uri  => ["/dashboard/csp_report"],

      :default_src => ["'self'"],
      :connect_src => ["'self'"],
      :font_src    => ["'self'", 'https://fonts.gstatic.com', "https://fonts.googleapis.com"],
      :frame_src   => ["'self'"],
      :img_src     => ["'self'", "data:"],
      :object_src  => ["'self'"],
      :script_src  => ["'unsafe-eval'", "'unsafe-inline'", "'self'"],
      :style_src   => ["'unsafe-inline'", "'self'", "https://fonts.googleapis.com", "https://fonts.gstatic.com"]
    }
  end
end
