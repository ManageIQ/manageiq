require 'websocket/driver'

module RemoteConsole
  module ClientAdapter
    class WebMKS < SSLSocket
      attr_accessor :url

      def initialize(record, socket)
        super(record, socket)
        # Initialize the WebSocket::Driver client
        @url = URI::Generic.build(:scheme => 'wss',
                                  :host   => @record.host_name,
                                  :port   => @record.port,
                                  :path   => path).to_s
        @driver = WebSocket::Driver.client(self, :protocols => [protocol])
        @driver.on(:close) { socket.close unless socket.closed? }
        @driver.start
      end

      def fetch(length)
        # This callback should be set just once, yielding with the parsed message
        @driver.on(:message) { |msg| yield(msg.data) } if @driver.listeners(:message).length.zero?

        data = @ssl.send(:sysread_nonblock, length, :exception => false)
        # Parse the incoming data, run the callback from above
        @driver.parse(data) if data != :wait_readable
      end

      def issue(data)
        @driver.binary(data)
      end

      def write(data)
        @ssl.syswrite(data)
      end

      private

      def protocol
        'binary'.freeze
      end

      def path
        "/ticket/#{@record.secret}"
      end
    end
  end
end
