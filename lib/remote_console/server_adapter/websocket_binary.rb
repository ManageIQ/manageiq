module RemoteConsole
  module ServerAdapter
    class WebsocketBinary
      attr_reader :env, :url

      def initialize(env, sock)
        @env = env
        @sock = sock

        secure = Rack::Request.new(env).ssl?
        scheme = secure ? 'wss:' : 'ws:'
        @url = scheme + '//' + env['HTTP_HOST'] + env['REQUEST_URI']

        @driver = WebSocket::Driver.rack(self, :protocols => [protocol])
        @driver.on(:close) { @sock.close unless sock.closed? }

        @driver.start
      end

      def fetch(length)
        @driver.on(:message) { |msg| yield(msg.data.pack('C*')) } if @driver.listeners(:message).length.zero?

        data = @sock.read_nonblock(length)
        @driver.parse(data)
      end

      def issue(data)
        @driver.binary(data)
      end

      def write(data)
        @sock.write_nonblock(data)
      end

      private

      def protocol
        'binary'.freeze
      end
    end
  end
end
