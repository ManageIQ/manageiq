if defined?(SecureHeaders)
  # Please make sure these values are properly reflected in apache config:
  # - https://github.com/ManageIQ/manageiq-appliance/blob/master/COPY/etc/httpd/conf.d/manageiq-https-application.conf
  # - https://github.com/ManageIQ/manageiq-pods/blob/master/manageiq-operator/pkg/helpers/miq-components/httpd_conf.go
  SecureHeaders::Configuration.default do |config|
    # Opt out of secure_headers cookie middleware - we manage session cookie
    # security ourselves via ManageIQ::Session::AbstractStoreAdapter#session_options:
    #   same_site: :strict  (always)
    #   secure:    true     (appliance only, unless ALLOW_INSECURE_SESSION)
    #   httponly:  true     (appliance only)
    # The gem's SameSite=Lax default is weaker than our Strict setting.
    # Note: ws_token (ActionCable auth) is set by JavaScript via document.cookie
    # and is not subject to this middleware, so it is unaffected either way.
    config.cookies = SecureHeaders::OPT_OUT
    # Only set HSTS in development/test where Apache isn't fronting Rails
    # In production, Apache sets HSTS (see manageiq-https-application.conf line 15)
    config.hsts = Rails.env.production? ? SecureHeaders::OPT_OUT : "max-age=#{20.years.to_i}"
    # X-Frame-Options
    config.x_frame_options = 'SAMEORIGIN'
    # X-Content-Type-Options
    config.x_content_type_options = "nosniff"
    # X-XSS-Protection
    # X-Permitted-Cross-Domain-Policies

    # TODO: This was deprecated and disabled in rails 7.  Using content security policy is the desired behavior going forward:
    # https://github.com/rails/rails/commit/1f4714c3f798df227222f531141880b8e1b4170a
    # https://github.com/rails/rails/blob/d437ae311f1b9dc40b442e40eb602e020cec4e49/railties/lib/rails/application/configuration.rb#L227
    # Once we remove unsafe-inline, then we can set this to the default, 0. Since we still use unsafe-inline, we still use X-XSS-Protection.
    # From: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/X-XSS-Protection
    # "The HTTP X-XSS-Protection response header was a feature of Internet Explorer, Chrome and Safari that stopped pages from loading when
    # they detected reflected cross-site scripting (XSS) attacks. These protections are largely unnecessary in modern browsers when sites
    # implement a strong Content-Security-Policy that disables the use of inline JavaScript ('unsafe-inline')."
    config.x_xss_protection = "1; mode=block"
    config.referrer_policy = "no-referrer-when-downgrade"
    # Content-Security-Policy
    # Need google fonts in fonts_src for https://fonts.googleapis.com/css?family=IBM+Plex+Sans+Condensed%7CIBM+Plex+Sans:400,600&display=swap (For carbon-charts download)
    config.csp = {
      :report_uri  => ["/dashboard/csp_report"],
      # report-to enables modern structured CSP reporting. Browsers that support the Reporting API
      # use this; others fall back to report-uri. The Reporting-Endpoints header that names
      # csp-endpoint is set by Apache (see manageiq-appliance and manageiq-pods httpd configs).
      :report_to   => "csp-endpoint",

      :base_uri        => ["'self'"],
      :default_src     => ["'self'"],
      :connect_src     => ["'self'"],
      :font_src        => ["'self'", 'https://fonts.gstatic.com', "https://fonts.googleapis.com"],
      :form_action     => ["'self'"],
      :frame_ancestors => ["'self'"],
      :frame_src       => ["'self'"],
      :img_src         => ["'self'", "data:"],
      :object_src      => ["'self'"],
      :script_src      => ["'unsafe-eval'", "'unsafe-inline'", "'self'"],
      :style_src       => ["'unsafe-inline'", "'self'", "https://fonts.googleapis.com", "https://fonts.gstatic.com"],
      :worker_src      => ["'self'"]
    }
  end
end
