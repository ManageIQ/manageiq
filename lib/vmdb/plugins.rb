module Vmdb
  class Plugins
    include Singleton

    attr_reader :vmdb_plugins
    attr_reader :registered_automate_domains

    def initialize
      @registered_automate_domains = []
      @vmdb_plugins = []
    end

    def register_vmdb_plugin(engine)
      @vmdb_plugins << engine

      register_automate_domains(engine)

      # make sure STI models are recognized
      DescendantLoader.instance.descendants_paths << engine.root.join('app')
    end

    def register_automate_domains(engine)
      Dir.glob(engine.root.join("content", "automate", "*")).each do |domain_directory|
        @registered_automate_domains << AutomateDomain.new(domain_directory)
      end
    end

    def system_automate_domains
      registered_automate_domains.select(&:system?)
    end
  end
end
