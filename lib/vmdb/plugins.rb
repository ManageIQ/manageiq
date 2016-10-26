module Vmdb
  class Plugins
    include Singleton

    attr_reader :vmdb_plugins

    def initialize
      @vmdb_plugins = []
    end

    def register_vmdb_plugin(engine)
      @vmdb_plugins << engine

      # make sure STI models are recognized
      DescendantLoader.instance.descendants_paths << engine.root.join('app')
    end
  end
end
