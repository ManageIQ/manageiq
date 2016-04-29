class WebsocketServer
  Pairing = Struct.new(:is_ws, :proxy)

  def initialize
    @pairing = {}
    @sockets = Concurrent::Array.new
    @pending = Concurrent::Array.new

    # Transmitter thread
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

    # Connector thread
    Thread.new do
      loop do
        opens = @pending
        reads, writes, _ = IO.select(nil, opens.map(&:sock), nil, 1)
        writes = [] if reads.nil?

        ready = opens.group_by { |proxy| writes.include?(proxy.sock) }

        if ready.empty?
          sleep(1)
          next
        end

        # Deal with timed out connections
        Array(ready[false]).each do |proxy|
          cleanup_pending(proxy)
        end

        # Deal with connections which are ready for write
        Array(ready[true]).each do |proxy|
          begin
            proxy.connect
          rescue Errno::EISCONN
            proxy.ts = nil
            proxy.init_ssl

            @pairing.merge!(proxy.ws => Pairing.new(true, proxy), proxy.sock => Pairing.new(false, proxy))
            @sockets.push(proxy.ws, proxy.sock)

            @pending.delete(proxy)
          rescue IO::WaitWritable
            cleanup_pending(proxy)
          rescue
            cleanup_pending(proxy, true)
          end
        end
      end
    end
  end

  def call(env)
    if WebSocket::Driver.websocket?(env)
      exp = %r{^/ws/console/([a-zA-Z0-9]+)/?$}.match(env['REQUEST_URI'])
      return not_found if exp.nil?

      console = SystemConsole.find_by!(:url_secret => exp[1])

      proxy = WebsocketProxy.new(env, console).start

      # Pass the proxy to the connector thread
      @pending.push(proxy) unless proxy.error

      # Release the connection because one SPICE console can open multiple TCP connections
      ActiveRecord::Base.connection_pool.release_connection

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

  def cleanup_pending(proxy, force = false)
    return unless proxy.timeout? || force
    @pending.delete(proxy)
    proxy.cleanup
  end

  def not_found
    [404, {'Content-Type' => 'text/plain'}, ['Not found']]
  end
end
