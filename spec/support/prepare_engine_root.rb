# Helper that sets up ENGINE_ROOT if running from within a plugin. This is normally
# setup by bin/rails or in the plugin Rakefile via rails/tasks/engine.rake,
# however it's possible to bypass those, such as when running `rspec`.
#
# `find_engine_path` and parts of `define_engine_root` are copied from Rails'
# rails/tasks/engine.rake which detects the ENGINE_ROOT for use in Rake tasks.
module Spec
  module Support
    module PrepareEngineRoot
      def self.setup
        define_engine_root
      end

      def self.find_engine_path(path)
        return File.expand_path(Dir.pwd) if path.root?

        if Rails::Engine.find(path)
          path.to_s
        else
          find_engine_path(path.join(".."))
        end
      end

      def self.define_engine_root
        if !defined?(::ENGINE_ROOT) || !::ENGINE_ROOT
          engine_path = find_engine_path(Pathname.new(Dir.pwd))
          Object.const_set("ENGINE_ROOT", engine_path) if Rails.root.to_s != engine_path
        end
      end
    end
  end
end
