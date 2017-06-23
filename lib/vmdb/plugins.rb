module Vmdb
  class Plugins
    include Singleton

    attr_reader :registered_automate_domains

    def initialize
      @registered_automate_domains = []
      @registered_provider_plugin_map = {}
      @vmdb_plugins = []
    end

    def vmdb_plugins
      @vmdb_plugins.empty? ? register_vmdb_plugins : @vmdb_plugins
    end

    def register_vmdb_plugins
      plugin_registry.plugins.each do |plugin|
        register_vmdb_plugin(plugin)
      end

      @vmdb_plugins
    end

    def register_vmdb_plugin(plugin)
      @vmdb_plugins << plugin

      register_automate_domains(plugin)
      register_provider_plugin(plugin)

      # make sure STI models are recognized
      DescendantLoader.instance.descendants_paths << plugin.root.join('app')
    end

    def registered_provider_plugin_names
      @registered_provider_plugin_map.keys
    end

    def registered_provider_plugins
      @registered_provider_plugin_map.values
    end

    def system_automate_domains
      registered_automate_domains.select(&:system?)
    end

    private

    def plugin_registry
      @plugin_registry ||= build_plugin_registry
    end

    def build_plugin_registry
      if defined?(Rails)
        require_relative "plugins/registry/rails.rb"
        Vmdb::Plugins::Registry::Rails.instance
      else
        require_relative "plugins/registry/bundler.rb"
        Vmdb::Plugins::Registry::Bundler.instance
      end
    end

    def register_provider_plugin(plugin)
      if plugin_registry.provider_plugin? plugin
        provider_name = plugin_registry.provider_name(plugin)
        @registered_provider_plugin_map[provider_name] = plugin
      end
    end

    def register_automate_domains(plugin)
      Dir.glob(plugin.root.join("content", "automate", "*")).each do |domain_directory|
        @registered_automate_domains << AutomateDomain.new(domain_directory)
      end
    end
  end
end
