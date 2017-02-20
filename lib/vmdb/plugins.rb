module Vmdb
  class Plugins
    include Singleton

    attr_reader :vmdb_plugins
    attr_reader :registered_automate_domains

    def initialize
      @registered_automate_domains = []
      @registered_provider_plugin_map = {}
      @vmdb_plugins = []
    end

    def register_vmdb_plugin(engine)
      @vmdb_plugins << engine

      register_automate_domains(engine)
      register_provider_plugin(engine)

      # make sure STI models are recognized
      DescendantLoader.instance.descendants_paths << engine.root.join('app')
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

    def register_provider_plugin(engine)
      if engine.class.name.start_with?("ManageIQ::Providers::")
        provider_name = ManageIQ::Providers::Inflector.provider_name(engine).underscore.to_sym
        @registered_provider_plugin_map[provider_name] = engine
      end
    end

    def register_automate_domains(engine)
      Dir.glob(engine.root.join("content", "automate", "*")).each do |domain_directory|
        @registered_automate_domains << AutomateDomain.new(domain_directory)
      end
    end
  end
end
