module Vmdb
  class Settings
    class DatabaseSource
      include Vmdb::Logging

      attr_reader :resource, :settings_change_holder

      def initialize(resource_to_get_settings_about, class_to_call_settings_changes_on)
        @resource = resource_to_get_settings_about
        @settings_change_holder = class_to_call_settings_changes_on
      end

      def self.sources_for(resource_to_get_settings_about)
        return [] if resource_to_get_settings_about.nil?
        hierarchy_index = SETTINGS_HIERARCHY.index(resource_to_get_settings_about.class.name.to_sym)
        SETTINGS_HIERARCHY[0..hierarchy_index].collect do |class_to_call_settings_changes_on|
          new(resource_to_get_settings_about, class_to_call_settings_changes_on)
        end
      end

      def self.parent_sources_for(resource_to_get_settings_about)
        return [] if resource_to_get_settings_about.nil?
        hierarchy_index = SETTINGS_HIERARCHY.index(resource_to_get_settings_about.class.name.to_sym)
        SETTINGS_HIERARCHY[0..hierarchy_index][0...-1].collect do |class_to_call_settings_changes_on|
          new(resource_to_get_settings_about, class_to_call_settings_changes_on)
        end
      end

      def load
        return if resource.nil?
        obj_with_settings = settings_holder
        obj_with_settings.settings_changes.reload.each_with_object({}) do |c, h|
          h.store_path(c.key_path, c.value)
        end unless obj_with_settings.nil?
      rescue => err
        _log.error("#{err.class}: #{err}")
        _log.error(err.backtrace.join("\n"))
        raise
      end

      private

      METHODS_FOR_SETTINGS = %i(miq_region zone miq_server).freeze
      SETTINGS_HIERARCHY = %i(MiqRegion Zone MiqServer).freeze

      def settings_holder
        direct_call = true
        if resource
          direct_call = resource.class.name.to_sym == settings_change_holder
        end
        return resource if direct_call
        ind = SETTINGS_HIERARCHY.index(settings_change_holder)
        resource.reload.send(METHODS_FOR_SETTINGS[ind])
      end
    end
  end
end
