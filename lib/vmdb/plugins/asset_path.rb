require_relative '../inflections'
Vmdb::Inflections.load_inflections

module Vmdb
  class Plugins
    class AssetPath
      attr_reader :name
      attr_reader :path
      attr_reader :namespace

      def self.asset_path(engine)
        engine.root.join('app', 'javascript')
      end

      def self.asset_path?(engine)
        asset_path(engine).directory?
      end

      def initialize(engine)
        asset_path = self.class.asset_path(engine)
        raise "#{asset_path} does not exist" unless asset_path.directory?

        @name      = engine.name
        @path      = engine.root
        @namespace = name.chomp("::Engine").underscore.tr("/", "-")
      end
    end
  end
end
