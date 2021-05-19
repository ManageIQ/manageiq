<% exploded_class_name do %>
  class Engine < ::Rails::Engine
    isolate_namespace <%= class_name %>

    config.autoload_paths << root.join('lib').to_s

    initializer :append_secrets do |app|
      app.config.paths["config/secrets"] << root.join("config", "secrets.defaults.yml").to_s
      app.config.paths["config/secrets"] << root.join("config", "secrets.yml").to_s
    end

    def self.vmdb_plugin?
      true
    end

    def self.plugin_name
      _('<%= plugin_human_name %>')
    end

    def self.init_loggers
      $<%= plugin_short_name %>_log ||= Vmdb::Loggers.create_logger("<%= plugin_short_name %>.log")
    end

    def self.apply_logger_config(config)
      Vmdb::Loggers.apply_config_value(config, $<%= plugin_short_name %>_log, :level_<%= plugin_short_name %>)
    end
  end
<% end %>
