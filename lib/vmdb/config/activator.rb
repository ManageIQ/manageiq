module VMDB
  class Config
    class Activator
      def initialize(config)
        @config = config.respond_to?(:config) ? config.config : config
      end

      def activate
        raise "configuration invalid, see errors for details" unless Validator.new(@config).valid?

        @config.each_key do|k|
          if respond_to?(k.to_s, true)
            ost = OpenStruct.new(@config[k].stringify_keys)
            send(k.to_s, ost)
          end
        end
      end

      private

      def log(data)
        Vmdb::Loggers.apply_config(data)
      end

      def ntp(_data)
        MiqServer.my_server.ntp_reload_queue unless MiqServer.my_server.nil? rescue nil
      end

      def session(data)
        Session.timeout data.timeout
        Session.interval data.interval
      end

      def server(data)
        MiqServer.my_server.config_updated(data) unless MiqServer.my_server.nil? rescue nil
      end
    end
  end
end
