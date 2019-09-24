require 'websocket/driver'

module RemoteConsole
  module ServerAdapter
    class WebsocketBinary
      attr_reader :env, :url

      def initialize(env, sock)
        @env = env
        @sock = sock

        # Determine if we're on SSL or not
        secure = Rack::Request.new(env).ssl?
        scheme = secure ? 'wss:' : 'ws:'
        # The HTTP_HOST is already in the right form when it is IPv6 and it can also contain a port number,
        # therefore, URI::Generic cannot deal with it and it is safe to just concatenate the two strings.
        @url = scheme + '//' + env['HTTP_HOST'] + env['REQUEST_URI']

        # Initialize the websocket connection from the Rack environment
        @driver = WebSocket::Driver.rack(self, :protocols => [protocol])
        @driver.on(:close) { @sock.close unless sock.closed? }

        @driver.start
      end

      # Due to the WebSocket::Driver's asychronous parse vs on-message implementation it is not possible
      # to provide the data as the return value of this method. Instead of this the method yields when
      # the message has been parsed, so any further operation with the data is available in a block passed
      # into this method.
      def fetch(length)
        # This callback should be set just once, yielding with the parsed message
        @driver.on(:message) { |msg| yield(msg.data.pack('C*')) } if @driver.listeners(:message).length.zero?

        data = @sock.read_nonblock(length) # Read from the socket
        @driver.parse(data) # Parse the incoming data, run the callback from above
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
