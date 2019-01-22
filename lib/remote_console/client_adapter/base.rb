module RemoteConsole
  module ClientAdapter
    class Base
      attr_reader :record

      def initialize(record, socket)
        @record = record
        @sock = socket
      end

      def fetch(*)
        raise NotImplementedError, 'This should be defined in a subclass'
      end

      def issue(*)
        raise NotImplementedError, 'This should be defined in a subclass'
      end
    end
  end
end
