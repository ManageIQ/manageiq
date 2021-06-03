# To lazy load routes:
# 1) Modify the RoutesReloader to skip normal reload! unless opted-in or Rails server
# 2) Insert a Rack::Middleware to catch the first request with empty routes, opt-in and reload!
# 3) Modify the RoutesInspector used by rake routes to detect empty routes, opt-in and reload!
module RoutesReloaderLazyLoadRoutes
  def reload!
    if $force_routes_load || defined?(Rails::Server)
      puts "loading routes..."
      super
    end
  end
end
Rails::Application::RoutesReloader.prepend(RoutesReloaderLazyLoadRoutes)

class LazyLoadRoutesMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    if Rails.application.routes.empty?
      $force_routes_load = true
      Rails.application.reloader.reload!
    end
    @app.call(env)
  end
end
Rails.application.config.middleware.use LazyLoadRoutesMiddleware

module RoutesInspectorLazyLoadRoutes
  def format(*args)
    if @routes.empty?
      $force_routes_load = true
      Rails.application.reloader.reload!
    end
    super
  end
end

# This is loaded anyway by actionpack/lib/action_dispatch/middleware/debug_exceptions.rb
require "action_dispatch/routing/inspector"
ActionDispatch::Routing::RoutesInspector.prepend(RoutesInspectorLazyLoadRoutes)


module ACControllerLazyLoadRoutes
  def initialize(*args)
    if Rails.application.routes.empty?
      $force_routes_load = true
      Rails.application.reloader.reload!
      should_raise = false
    end
    super
  end
end

ActionController::Base.prepend(ACControllerLazyLoadRoutes)
ActionController::API.prepend(ACControllerLazyLoadRoutes)
ActionDispatch::Integration::Session.prepend(ACControllerLazyLoadRoutes)
