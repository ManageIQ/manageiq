require_relative '../inflections'
Vmdb::Inflections.load_inflections

module Vmdb
  class Plugins
    class AssetPath
      attr_reader :name
      attr_reader :path
      attr_reader :namespace
      attr_reader :node_modules

      def self.asset_path(engine)
        engine.root.join('app', 'javascript')
      end

      def self.asset_path?(engine)
        asset_path(engine).directory?
      end

      def initialize(engine)
        asset_path = self.class.asset_path(engine)
        raise "#{asset_path} does not exist" unless asset_path.directory?

        @name            = engine.name
        @path            = engine.root
        @namespace       = name.chomp("::Engine").underscore.tr("/", "-")
        @in_bundler_gems = engine.root.expand_path.to_s.start_with?(Bundler.install_path.expand_path.to_s)

        @node_modules = if @in_bundler_gems
                          self.class.node_root.join(@namespace)
                        else
                          @path
                        end.join('node_modules')
      end

      def development_gem?
        !@in_bundler_gems
      end

      # also used in update:ui task to determine where to copy config files
      def self.node_root
        Rails.root.join('vendor', 'node_root')
      end
    end
  end
end
