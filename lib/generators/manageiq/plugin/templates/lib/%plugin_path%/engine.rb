<% exploded_class_name do %>
  class Engine < ::Rails::Engine
    isolate_namespace <%= class_name %>

    config.autoload_paths << root.join('lib').to_s

    def self.vmdb_plugin?
      true
    end

    def self.plugin_name
      _('<%= plugin_human_name %>')
    end
  end
<% end %>
