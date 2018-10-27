module Vmdb
  class Settings
    class DatabaseSource
      include Vmdb::Logging

      attr_reader :settings_holder_class_name

      # @param resource [MiqRegion, Zone, MiqServer, :my_server] the resource
      #   If passed :my_server, then MiqServer.my_server will be dynamically called.
      # @param class_name [String] class name of object which provides access to SettingsChange for resource
      #   possible values of class_name are {DatabaseSource::SETTINGS_HIERARCHY the setting hierarchy}
      #
      #   Example:
      #   1. resource is instance of MiqServer and class_name is 'Zone', then settings will be loaded
      #      from resource.zone.settings_changes
      #   2. resource is instance of MiqServer and class_name is 'MiqRegion', then settings will be loaded
      #      from resource.miq_region.settings_changes
      def initialize(resource, class_name)
        raise ArgumentError, "resource cannot be nil" if resource.nil?

        @resource_instance = resource
        @settings_holder_class_name = class_name.to_s
      end

      def self.sources_for(resource)
        return [] if resource.nil?
        resource_class = resource == :my_server ? "MiqServer" : resource.class.name
        hierarchy_index = SETTINGS_HIERARCHY.index(resource_class)
        SETTINGS_HIERARCHY[0..hierarchy_index].collect do |class_name|
          new(resource, class_name)
        end
      end

      def self.parent_sources_for(resource)
        sources_for(resource)[0...-1]
      end

      def resource
        return my_server if @resource_instance == :my_server
        @resource_instance.reload if @resource_instance.persisted?
        @resource_instance
      end

      def load
        holder = settings_holder
        if holder
          holder.settings_changes.reload.each_with_object({}) do |c, h|
            h.store_path(c.key_path, c.value)
          end
        end
      rescue => err
        _log.log_backtrace(err)
        raise
      end

      private

      SETTINGS_HIERARCHY = %w(MiqRegion Zone MiqServer).freeze

      def settings_holder
        resource = self.resource
        return nil if resource.nil?
        return resource if resource.class.name == settings_holder_class_name
        resource.public_send(settings_holder_class_name.underscore)
      end

      # Since `#load` occurs very early in the boot process, we must ensure that
      # we do not fail in cases where the database is not yet created, not yet
      # available, or has not yet been seeded.
      def my_server
        ::MiqServer.my_server(true) if resource_queryable?
      end

      def resource_queryable?
        database_connectivity? && ::SettingsChange.table_exists?
      end

      def database_connectivity?
        conn = ActiveRecord::Base.connection rescue nil
        conn && ActiveRecord::Base.connected?
      end
    end
  end
end
