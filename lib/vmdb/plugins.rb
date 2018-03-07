module Vmdb
  class Plugins
    include Singleton

    attr_reader :registered_automate_domains

    def initialize
      @registered_automate_domains = []
      @registered_provider_plugin_map = {}
      @registered_ansible_content = []
      @vmdb_plugins = []
    end

    def vmdb_plugins
      @vmdb_plugins.empty? ? register_vmdb_plugins : @vmdb_plugins
    end

    def register_vmdb_plugins
      Rails.application.railties.each do |railtie|
        next unless railtie.class.name.start_with?("ManageIQ::Providers::") || railtie.try(:vmdb_plugin?)
        register_vmdb_plugin(railtie)
      end

      @vmdb_plugins
    end

    def register_vmdb_plugin(engine)
      @vmdb_plugins << engine

      register_automate_domains(engine)
      register_ansible_content(engine)
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

    def registered_content_directories(engine, subfolder)
      Dir.glob(engine.root.join("content", subfolder, "*")).each do |content_directory|
        yield content_directory
      end
    end

    def register_automate_domains(engine)
      registered_content_directories(engine, "automate") do |domain_directory|
        @registered_automate_domains << AutomateDomain.new(domain_directory)
      end
    end

    def register_ansible_content(engine)
      registered_content_directories(engine, "ansible") do |content_directory|
        @registered_ansible_content << AnsibleContent.new(content_directory)
      end
    end
  end
end
