# Settings for integration testings.  A mix between development and production,
# using production as a base and pulling in specific options from development
# where appropriate.
#
Vmdb::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  config.eager_load_paths = []

  # Code is not reloaded between requests unless CYPRESS_DEV is set
  #
  # Idea borrowed from:
  #
  #   https://blog.simplificator.com/2019/10/11/setting-up-cypress-with-rails/
  #
  # We want this to be "production-like" unless CYPRESS_DEV is present
  config.cache_classes = ENV['CYPRESS_DEV'].blank?
  config.eager_load = false

  # Log error messages when you accidentally call methods on nil.
  #
  # Pulled from `config/environment/development.rb`, but only enable if
  # ENV['CYPRESS_DEV']
  #
  config.whiny_nils = true if ENV['CYPRESS_DEV'].present?

  # Full error reports are disabled and caching is turned on
  #
  # Same in development and production
  config.consider_all_requests_local       = false

  # Enable caching by default, but disable it when running with CYPRESS_DEV
  #
  # Same default as production, setting CYPRESS_DEV sets it to development-like
  config.action_controller.perform_caching = ENV['CYPRESS_DEV'].blank?

  # Don't care if the mailer can't send
  #
  # Matching development here, commented out on production
  config.action_mailer.raise_delivery_errors = false

  # Print deprecation notices to the Rails logger.
  #
  # Same in development and production
  config.active_support.deprecation = :log

  # Disable serving static files from the `/public` folder by default since
  # Apache or NGINX already handles this.
  #
  # Using production environment variable, and added headers addition from
  # test.rb (`.enabled` should default to `true` in `Rails.env.development?`)
  if ENV['RAILS_SERVE_STATIC_FILES'].present?
    config.public_file_server.enabled = true
    config.public_file_server.headers = {'Cache-Control' => 'public, max-age=3600'}
  end

  # Compress JavaScripts and CSS
  #
  # Production defaults this to true, so matching that.  Development and test
  # are both `false`, so CYPRESS_DEV=1 will match that.
  config.assets.compress = ENV['CYPRESS_DEV'].blank?

  # This setting has a confusing name...
  #
  # if false:  Do not fallback to assets pipeline if an asset is missing.
  # if true:   Use assets pipeline if an asset is missing.
  #
  # Defaults to true in `sprockets-rails`:
  #
  #   https://github.com/rails/sprockets-rails/blob/df46170c/lib/sprockets/railtie.rb#L120
  #
  # Matches for production by default, configurable to true via CYPRESS_DEV
  config.assets.compile = ENV['CYPRESS_DEV'].present?

  # Generate digests for assets URLs
  #
  # Defaults to true in `sprockets-rails`:
  #
  #   https://github.com/rails/sprockets-rails/blob/df46170c/lib/sprockets/railtie.rb#L121
  #
  # Matches for production by default
  config.assets.digest = true

  # Include miq_debug in the list of assets here because it is only used in development
  #
  # Pulled from development.  Doesn't hurt being in regardless
  config.assets.precompile << 'miq_debug.js'
  config.assets.precompile << 'miq_debug.css'

  # See everything in the log.  Default is :debug I think...
  #
  #   https://github.com/rails/rails/blob/7b5cc5a5/railties/lib/rails/application/configuration.rb#L40
  #
  config.log_level = :debug

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  #
  # Copied from production
  config.i18n.fallbacks = [I18n.default_locale]

  # Do not include all helpers for all views
  #
  # Shared across test/development/production
  config.action_controller.include_all_helpers = false

  # The test environment has this disabled, but matching development/production
  # makes the most sense when dealing with the UI.
  config.action_controller.allow_forgery_protection = true

  # Copied from production.  Not set in test/development environments
  config.assets.css_compressor = :sass
end
