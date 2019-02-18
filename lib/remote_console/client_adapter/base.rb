module RemoteConsole
  module ClientAdapter
    # All remote console clients should be inherited from this class
    class Base
      attr_reader :record

      def initialize(record, socket)
        @record = record
        @sock = socket
      end

      # This method should yield with the data received from the socket
      def fetch(*)
        raise NotImplementedError, 'This should be defined in a subclass'
      end

      # This method should be just a simple wrapper around writing to the socket
      def issue(*)
        raise NotImplementedError, 'This should be defined in a subclass'
      end
    end
  end
end
