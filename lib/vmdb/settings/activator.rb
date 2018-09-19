module Vmdb
  class Settings
    class Activator
      include Vmdb::Logging

      def initialize(config)
        @config =
          if config.kind_of?(::Config::Options)
            config.to_hash
          elsif config.respond_to?(:config)
            config.config
          else
            config
          end
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
