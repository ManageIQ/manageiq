module RemoteConsole
  module ServerAdapter
    class WebsocketUint8Utf8 < WebsocketBinary
      def issue(data)
        @driver.frame(data)
      end

      private

      def protocol
        'uint8utf8'.freeze
      end
    end
  end
end
