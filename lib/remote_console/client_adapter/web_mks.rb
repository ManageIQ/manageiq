module RemoteConsole
  module ClientAdapter
    class WebMKS < SSLSocket
      attr_accessor :url

      def initialize(record, socket)
        super(record, socket)
        @url = URI::Generic.build(:scheme => 'wss',
                                  :host   => @record.host_name,
                                  :port   => @record.port,
                                  :path   => path).to_s
        @driver = WebSocket::Driver.client(self, :protocols => [protocol])
        @driver.on(:close) { socket.close unless socket.closed? }
        @driver.start
      end

      def fetch(length)
        @driver.on(:message) { |msg| yield(msg.data) } if @driver.listeners(:message).length.zero?

        data = @ssl.sysread(length)
        @driver.parse(data)
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
