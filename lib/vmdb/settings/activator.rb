module Vmdb
  class Settings
    class Activator
      include Vmdb::Logging

      def initialize(config)
        @config = config.to_hash
      end

      def activate
        raise "configuration invalid, see errors for details" unless Validator.new(@config).valid?

        @config.each_key do |k|
          next unless respond_to?(k.to_s, true)

          _log.debug("Activating #{k}")
          ost = OpenStruct.new(@config[k].stringify_keys)
          send(k.to_s, ost)
        end
      end

      private

      def log(data)
        Vmdb::Loggers.apply_config(data)
      end

      def event_handling(_data)
        EmsEvent.clear_event_groups_cache
        EventStream.clear_event_groups_cache
      end

      def prototype(_data)
        Menu::Manager.reload if defined?(Menu::Manager) # NOTE: Can be removed after Settings.prototype.ems_workflows is removed
      end

      def session(data)
        Session.timeout(data.timeout)
        Session.interval(data.interval)
      end

      def server(data)
        MiqServer.my_server&.config_activated(data)
      rescue StandardError
        nil
      end
    end
  end
end
