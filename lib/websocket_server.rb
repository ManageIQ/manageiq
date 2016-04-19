class WebsocketServer
  Pairing = Struct.new(:is_ws, :proxy)

  def initialize
    @pairing = {}
    @sockets = Concurrent::Array.new

    Thread.new do
      errors = []
      loop do
        begin
          reads, writes, errors = IO.select(@sockets, @sockets, @sockets, 1)
        rescue IOError
          cleanup(errors)
        end

        # Skip this loop if we can't do anything
        next if Array(reads).empty? || writes.empty? || errors.any?

        # Do the data transfers
        reads.each do |read|
          @pairing[read].proxy.transmit(writes, @pairing[read].is_ws)
        end
      end
    end
  end

  def call(env)
    if WebSocket::Driver.websocket?(env)
      exp = %r{^/ws/console/([a-zA-Z0-9]+)/?$}.match(env['REQUEST_URI'])
      return not_found if exp.nil?

      console = SystemConsole.find_by!(:url_secret => exp[1])
      proxy = WebsocketProxy.new(env, console)
      return proxy.cleanup if proxy.error
      proxy.start

      # Release the connection because one SPICE console can open multiple TCP connections
      ActiveRecord::Base.connection_pool.release_connection

      ws, sock = proxy.descriptors
      @pairing.merge!(ws => Pairing.new(true, proxy), sock => Pairing.new(false, proxy))
      @sockets.push(ws, sock)

      [-1, {}, []]
    else
      not_found
    end
  end

  private

  def cleanup(errors)
    (@sockets.select(&:closed?) + errors).uniq.each do |socket|
      @pairing[socket].proxy.cleanup
      @sockets.delete(socket)
      @pairing.delete(socket)
    end
  end

  def not_found
    [404, {'Content-Type' => 'text/plain'}, ['Not found']]
  end
end
