if defined?(Rails::Server) && !Rails.env.test?
  require 'rack/attack'

  # The `rack/attack/railtie.rb` creates a `initializer` call, which is loaded
  # too late because of the `:require => false` in our Gemfile, so this needs
  # to be done manually.
  Rails.application.middleware.use(Rack::Attack)

  api_login_limit  = proc { Settings.server.rate_limiting.api_login.limit }
  api_login_period = proc { Settings.server.rate_limiting.api_login.period.to_i_with_method }
  request_limit    = proc { Settings.server.rate_limiting.request.limit }
  request_period   = proc { Settings.server.rate_limiting.request.period.to_i_with_method }
  ui_login_limit   = proc { Settings.server.rate_limiting.ui_login.limit }
  ui_login_period  = proc { Settings.server.rate_limiting.ui_login.period.to_i_with_method }

  # Throttle all requests by IP
  #
  # Key: "rack::attack:#{Time.now.to_i/:period}:req/ip:#{req.ip}"
  Rack::Attack.throttle('req/ip', :limit => request_limit, :period => request_period) do |req| # rubocop:disable Style/SymbolProc
    req.ip
  end

  # Throttle POST requests to /login by IP address
  #
  # Key: "rack::attack:#{Time.now.to_i/:period}:logins/ip:#{req.ip}"
  Rack::Attack.throttle('logins/ip', :limit => api_login_limit, :period => api_login_period) do |req|
    if req.path == "/api/auth" && req.post?
      req.ip
    end
  end

  Rack::Attack.throttle('logins/ip', :limit => ui_login_limit, :period => ui_login_period) do |req|
    if req.path == "/dashboard/authenticate" && req.post?
      req.ip
    end
  end
end
