require File.expand_path('boot', __dir__)
require File.expand_path('preinitializer', __dir__)
require 'rails'
require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'action_mailer/railtie'
require 'active_job/railtie'
require 'sprockets/railtie'
require 'action_cable/engine'

# We use bundler groups to select which dependencies to require in our different processes.
#  * Anything not in a group are in bundler's 'default' group, and are required all the time
#  * Anything in development, test, or production will get required by Bundler.require(*Rails.groups) in application.rb
#    See: https://github.com/rails/rails/blob/c48b21685f4fec1c7a1c9b4e0dde4da89140ee22/railties/lib/rails.rb#L81-L101
#
#  Loading application.rb requires any additional BUNDLER_GROUPS based on the environment variable.
#  This variable should be a comma separated list of groups.
#  The default BUNDLER_GROUPS below includes all bundler groups not in the Rails.groups.
#
ENV['BUNDLER_GROUPS'] ||= "manageiq_default,ui_dependencies"

if defined?(Bundler)
  groups = ENV['BUNDLER_GROUPS'].split(",").collect(&:to_sym)

  if $DEBUG
    puts "** Loading Rails bundler groups: #{Rails.groups.inspect}"
    puts "** Loading other bundler groups: #{groups.inspect}"
  end

  Bundler.require(*Rails.groups, *groups)
end

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
    config.filter_parameters += [:password, :verify, :data, :auth_key, :_pwd, :__protected]

    # Enable escaping HTML in JSON.
    config.active_support.escape_html_entities_in_json = true

    # Use SQL instead of Active Record's schema dumper when creating the database.
    # This is necessary if your schema can't be completely dumped by the schema dumper,
    # like if you have constraints or database-specific column types
    # config.active_record.schema_format = :sql

    # Enable the asset pipeline
    config.assets.enabled = true

    # TODO: Move to asset pipeline enabled by moving assets from public to app/assets
    config.asset_path = "%s"

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.0'

    # Set the manifest file name so that we are sure it gets overwritten on updates
    config.assets.manifest = Rails.public_path.join('assets/.sprockets-manifest.json').to_s

    # Disable ActionCable's request forgery protection
    # This is basically matching a set of allowed origins which is not good for us
    config.action_cable.disable_request_forgery_protection = false
    # Matching the origin against the HOST header is much more convenient
    config.action_cable.allow_same_origin_as_host = true
    config.action_cable.mount_path = '/ws/notifications'

    # Rails 6.1.7+ has a protection to not lookup values by a large number.
    # A lookup/comparison with a large number (bigger than bigint)
    # needs to cast the db column to a double/numeric.
    # and that casting skips the index and forces a table scan
    #
    # https://discuss.rubyonrails.org/t/cve-2022-44566-possible-denial-of-service-vulnerability-in-activerecords-postgresql-adapter/82119
    config.active_record.raise_int_wider_than_64bit = false

    # Use yaml_unsafe_load for column serialization to handle Symbols
    config.active_record.use_yaml_unsafe_load = true

    # Customize any additional options below...

    config.autoload_paths += config.eager_load_paths

    config.autoloader = :zeitwerk

    # config.load_defaults 6.1
    # Disable defaults as ActiveRecord::Base.belongs_to_required_by_default = true causes MiqRegion.seed to fail validation on belongs_to maintenance zone

    # NOTE:  If you are going to make changes to autoload_paths, please make
    # sure they are all strings.  Rails will push these paths into the
    # $LOAD_PATH.
    #
    # More info can be found in the ruby-lang bug:
    #
    #   https://bugs.ruby-lang.org/issues/14372
    #
    config.autoload_paths << Rails.root.join("app/models/aliases").to_s
    config.autoload_paths << Rails.root.join("app/models/mixins").to_s
    config.autoload_paths << Rails.root.join("lib").to_s
    config.autoload_paths << Rails.root.join("lib/services").to_s

    config.autoload_once_paths << Rails.root.join("lib/vmdb/console_methods.rb").to_s

    require_relative '../lib/request_started_on_middleware'
    config.middleware.use RequestStartedOnMiddleware

    # enable to log session id for every request
    # require_relative '../lib/request_log_session_middleware'
    # config.middleware.use RequestLogSessionMiddleware

    # config.eager_load_paths accepts an array of paths from which Rails will eager load on boot if cache classes is enabled.
    # Defaults to every folder in the app directory of the application.

    # This must be done outside of initialization blocks
    #   as the Vmdb::Logging constant is needed very early
    require 'vmdb/logging'

    # This must be done outside of initialization blocks
    #   as rake tasks that do not use the environment still need to log
    require 'vmdb/loggers'
    Vmdb::Loggers.init
    config.logger = Vmdb.rails_logger
    config.colorize_logging = false

    config.before_initialize do
      require_relative 'environments/patches/database_configuration'

      # To evaluate settings or database.yml with encrypted passwords
      require 'manageiq-password'
      require 'manageiq/password/password_mixin'
      ManageIQ::Password.key_root = Rails.root.join("certs")

      require 'vmdb_helper'
    end

    # Note: If an initializer doesn't have an after, Rails will add one based
    # on the top to bottom order of initializer calls in the file.
    # Because this is easy to mess up, keep your initializers in order.
    initializer :load_inflections, :before => :init_vmdb_plugins do
      Vmdb::Inflections.load_inflections
    end

    initializer :init_vmdb_plugins, :before => :load_vmdb_settings do
      Vmdb::Plugins.init
    end

    initializer :load_vmdb_settings, :before => :load_config_initializers do
      Vmdb::Settings.init
      Vmdb::Loggers.apply_config(::Settings.log)
    end

    initializer :eager_load_all_the_things, :after => :load_config_initializers do
      if ENV['DEBUG_MANAGEIQ_ZEITWERK'].present?
        config.eager_load_paths += config.autoload_paths
        Vmdb::Plugins.each do |plugin|
          plugin.config.eager_load_paths += plugin.config.autoload_paths
        end
      end
    end

    config.after_initialize do
      Vmdb::Initializer.init
      ActiveRecord::Base.connection_pool.release_connection
      puts "** #{Vmdb::Appliance.BANNER}" unless Rails.env.production?

      YamlPermittedClasses.initialize_app_yaml_permitted_classes
    end

    console do
      # This is to include vmdb methods into the top level namespace of the
      # repl session being opened (either through `pry` or IRB)
      #
      # This takes a page from `pry-rails` and extends the TOPLEVEL_BINDING
      # instead of Rails::ConsoleMethods when adding the Vmdb::ConsoleMethods.
      #
      # https://github.com/rweng/pry-rails/blob/fe29ddcdd/lib/pry-rails/railtie.rb#L25
      #
      # Without pry, this isn't required and we could just include this into
      # the `Rails::ConsoleMethods`, but with `pry-rails`, this isn't possible
      # since the railtie for it is loaded first and will include
      # `Rails::ConsoleMethods` before we have a chance to modify them here.
      TOPLEVEL_BINDING.eval('self').extend(Vmdb::ConsoleMethods)

      # In test mode automatically load the spec helper which will, among other
      # things, find the factory definitions and load factory related methods.
      if Rails.env.test?
        require_relative '../spec/spec_helper'
      end
    end
  end
end
