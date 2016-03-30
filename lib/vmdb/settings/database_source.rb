module Vmdb
  class Settings
    class DatabaseSource
      include Vmdb::Logging

      attr_reader :resource

      def initialize(resource)
        @resource = resource
      end

      def load
        return if resource.nil?

        resource.settings_changes.reload.each_with_object({}) do |c, h|
          h.store_path(c.key_path, c.value)
        end
      rescue => err
        _log.error("#{err.class}: #{err}")
        _log.error(err.backtrace.join("\n"))
        raise
      end
    end
  end
end
