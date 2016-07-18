module Vmdb
  class Settings
    class DatabaseSource
      include Vmdb::Logging

      attr_reader :resource_instance, :settings_holder_class_name

      # @param resource [MiqRegion, Zone, MiqServer] the resource
      # @param class_name [Symbol] class name of object which provides access to SettingsChange for resource
      #   possible values of class_name are {DatabaseSource::SETTINGS_HIERARCHY the setting hierarchy}
      #
      #   Example:
      #   1. resource is instance of MiqServer and class_name is 'Zone', than settings will be loaded
      #      from resource.zone.settings_changes
      #   2. resource is instance of MiqServer and class_name is 'MiqRegion' than settings will be loaded
      #      from resource.miq_region.settings_changes
      def initialize(resource, class_name)
        @resource_instance = resource
        @settings_holder_class_name = class_name.to_sym
      end

      def self.sources_for(resource)
        return [] if resource.nil?
        hierarchy_index = SETTINGS_HIERARCHY.index(resource.class.name.to_sym)
        SETTINGS_HIERARCHY[0..hierarchy_index].collect do |class_name|
          new(resource, class_name)
        end
      end

      def self.parent_sources_for(resource)
        sources_for(resource)[0...-1]
      end

      def load
        holder = settings_holder
        if holder
          holder.settings_changes.reload.each_with_object({}) do |c, h|
            h.store_path(c.key_path, c.value)
          end
        end
      rescue => err
        _log.error("#{err.class}: #{err}")
        _log.error(err.backtrace.join("\n"))
        raise
      end

      private

      METHODS_FOR_SETTINGS = %i(miq_region zone miq_server).freeze
      SETTINGS_HIERARCHY = %i(MiqRegion Zone MiqServer).freeze

      def settings_holder
        return nil if resource_instance.nil?
        resource_instance.reload
        return resource_instance if resource_instance.class.name.to_sym == settings_holder_class_name

        index = SETTINGS_HIERARCHY.index(settings_holder_class_name)
        resource_instance.send(METHODS_FOR_SETTINGS[index])
      end
    end
  end
end
