module Vmdb
  class Plugins
    module Registry
      class Rails
        include Singleton

        attr_reader :plugins, :provider_plugins

        def initialize
          @plugins = fetch_plugins
        end

        def provider_name(plugin)
          ManageIQ::Providers::Inflector.provider_name(plugin).underscore.to_sym
        end

        def provider_plugin?(plugin)
          provider_plugins.include? plugin
        end

        private

        def fetch_plugins
          ::Rails.application.railties.select do |railtie|
            railtie.class.name.start_with?("ManageIQ::Providers::") || railtie.try(:vmdb_plugin?)
          end
        end

        def provider_plugins
          @provider_plugins ||= @plugins.select do |engine|
            engine.class.name.start_with?("ManageIQ::Providers::")
          end
        end
      end
    end
  end
end
