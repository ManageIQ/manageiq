Vmdb::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  config.eager_load_paths = []

  # In the development environment your application's code is reloaded on
  # every request.  This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = ENV.fetch("CYPRESS", false).to_s == "true"
  config.eager_load = false

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = false

  # Don't care if the mailer can't send
  config.action_mailer.raise_delivery_errors = false

  config.active_record.migration_error = :page_load

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin

  # Raise exception on mass assignment protection for Active Record models
  # TODO: Fix our code to abide by Rails mass_assignment protection:
  # http://jonathanleighton.com/articles/2011/mass-assignment-security-shouldnt-happen-in-the-model/
  # config.active_record.mass_assignment_sanitizer = :strict

  # Do not compress assets
  config.assets.compress = false

  # Expands the lines which load the assets
  config.assets.debug = true

  config.assets.quiet = true

  # Include miq_debug in the list of assets here because it is only used in development
  config.assets.precompile << 'miq_debug.js'
  config.assets.precompile << 'miq_debug.css'

  # Customize any additional options below...

  # Do not include all helpers for all views
  config.action_controller.include_all_helpers = false

  config.colorize_logging = true

  config.action_controller.allow_forgery_protection = true

  # Allow nip.io for development with external auth where hostnames are required
  config.hosts << "127.0.0.1.nip.io"
end
