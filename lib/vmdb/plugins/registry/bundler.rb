module Vmdb
  class Plugins
    module Registry
      class Bundler
        class Plugin
          def initialize(spec)
            @spec = spec
          end

          def name
            @spec.name
          end

          def root
            @root ||= Pathname.new @spec.gem_dir
          end
        end

        include Singleton

        # FIXME:  Don't rely on this constant for determining non-provider
        # based plugins
        #
        # Instead find a way to do the equaivalent of `vmdb_plugin?` without
        # having to load the class (file in the root, modularize the code
        # containing `def vmdb_root?`, etc.)
        NON_PROVIDER_PLUGINS = %w(automation_engine content ui-classic).freeze

        attr_reader :plugins, :provider_plugins

        def initialize
          @plugins = fetch_plugins
        end

        def provider_name(plugin)
          plugin.name.gsub("manageiq-providers-", "")
        end

        def provider_plugin?(plugin)
          provider_plugins.include? plugin
        end

        private

        def fetch_plugins
          plugin_gems.map do |spec|
            Plugin.new(spec)
          end
        end

        def plugin_gems
          ::Bundler.locked_gems.specs.select do |spec|
            spec.name.match(/^manageiq-(providers-.*|#{NON_PROVIDER_PLUGINS.join("|")})$/)
          end
        end

        def provider_plugins
          @provider_plugins ||= @plugins.select do |plugin|
            plugin.name.start_with?("manageiq-providers-")
          end
        end
      end
    end
  end
end
