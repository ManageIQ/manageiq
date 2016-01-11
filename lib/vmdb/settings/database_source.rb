module Vmdb
  class Settings
    class DatabaseSource
      include Vmdb::Logging

      def initialize(resource = nil)
        @resource = resource
      end

      def resource
        @resource ||= find_resource
      end

      def load
        return if resource.nil?

        resource.settings_changes.each_with_object({}) do |c, h|
          h.store_path(c.key_path, c.value)
        end
      rescue => err
        _log.error("#{err.class}: #{err}")
        _log.error(err.backtrace.join("\n"))
        raise
      end

      private

      # Since `#load` occurs very early in the boot process, we must ensure that
      # we do not fail in cases where the database is not yet created, not yet
      # available, or has not yet been seeded.
      def find_resource
        database_connectivity? && MiqServer.table_exists? ? MiqServer.my_server(true) : nil
      end

      def database_connectivity?
        conn = ActiveRecord::Base.connection rescue nil
        conn && ActiveRecord::Base.connected?
      end
    end
  end
end
