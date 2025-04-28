module Vmdb::Loggers
  class RequestLogger
    class Logdev
      attr_reader :resource_id

      def initialize(resource_id)
        @resource_id = resource_id
      end

      def write(message)
        severity, message = message.split(":", 2)

        RequestLog.create(:message => message, :severity => severity, :resource_id => resource_id)
      end
    end
  end
end
