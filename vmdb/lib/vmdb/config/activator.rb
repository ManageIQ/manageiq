module VMDB
  class Config
    class Activator
      def initialize(config)
        @config = config.respond_to?(:config) ? config.config : config
      end

      def activate
        raise "configuration invalid, see errors for details" unless Validator.new(@config).valid?

        @config.each_key {|k|
          if respond_to?(k.to_s, true)
            ost = OpenStruct.new(@config[k].stringify_keys)
            send(k.to_s, ost)
          end
        }
      end

      private

      def log(_data)
        Vmdb::Loggers.init
      end

      def session(data)
        Session.timeout data.timeout
        Session.interval data.interval
      end

      def server(data)
        MiqServer.my_server.config_updated(data, mode) unless MiqServer.my_server.nil? rescue nil
      end
    end
  end
end
