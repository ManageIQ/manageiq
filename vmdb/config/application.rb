require File.expand_path('../boot', __FILE__)
require File.expand_path('../preinitializer', __FILE__)
require 'rails/all'

if defined?(Bundler)
  Bundler.require *Rails.groups(:assets => %w(development test))
end

# Rails3 TODO: is this still required?
require 'yaml'
$ADAPTER = YAML::load_file(File.join(File.dirname(__FILE__), "database.yml"))[Rails.env]["adapter"].downcase

module Vmdb
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    # config.autoload_paths += %W(#{config.root}/extras)

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de
    config.i18n.enforce_available_locales = true

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password, :verify, :data, :_pwd, :__protected]

    # Enable escaping HTML in JSON.
    config.active_support.escape_html_entities_in_json = true

    # Use SQL instead of Active Record's schema dumper when creating the database.
    # This is necessary if your schema can't be completely dumped by the schema dumper,
    # like if you have constraints or database-specific column types
    # config.active_record.schema_format = :sql

    # Enable the asset pipeline
    config.assets.enabled = true

    # TODO: Move to asset pipeline enabled by moving assets from vmdb/public to vmdb/app/assets
    config.asset_path = "%s"

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.0'


    # Customize any additional options below...

    # HACK: By default, Rails.configuration.eager_load_paths contains all of the directories
    # in app and Rails.configuration.autoload_paths is empty.  Sometime during initialization,
    # these two arrays are combined and placed into ActiveSupport::Dependencies.autoload_paths,
    # which is what is used for autoloading.  Since we do not want to eager load anything due
    # to memory bloat, we clear out eager_load_paths down below.  This ends up leaving the
    # ActiveSupport::Dependencies.autoload_paths empty, thus breaking autoloading.  Thus, in
    # order to prevent eager loading, but still populate autoload_paths, we copy them.
    config.autoload_paths += config.eager_load_paths
    config.autoload_paths << Rails.root.join("app", "models", "mixins")
    config.autoload_paths << Rails.root.join("app", "controllers", "mixins")
    config.autoload_paths << Rails.root.join("lib")
    config.autoload_paths << Rails.root.join('app', 'presenters')

    # config.eager_load_paths accepts an array of paths from which Rails will eager load on boot if cache classes is enabled.
    # Defaults to every folder in the app directory of the application.
    config.eager_load_paths = []

    require_relative 'environments/patches/database_configuration'

    console do
      Rails::ConsoleMethods.class_eval do
        include Vmdb::ConsoleMethods
      end
    end

    #logging requires configuration which requires encryption
    require 'miq-password'
    MiqPassword.key_root=Rails.root.join("certs")

    require 'vmdb/logging'
    Vmdb::Logging.init
    config.logger = Vmdb.rails_logger
    config.colorize_logging = false

    config.after_initialize do
      Vmdb::Initializer.init
    end
  end
end
