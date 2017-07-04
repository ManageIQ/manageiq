class WebsocketServer
  attr_accessor :logger

  Pairing = Struct.new(:is_ws, :proxy)

  def initialize(options = {})
    @logger = options.fetch(:logger, $websocket_log)
    logger.info('Initializing websocket worker!')
    @pairing = {}
    @sockets = Concurrent::Array.new

    @transmitter = Thread.new do
      loop do
        begin
          reads, writes, errors = IO.select(@sockets, @sockets, @sockets, 1)
        rescue IOError
          @sockets.select(&:closed?).each { |err| cleanup(err) }
        else
          Array(errors).each { |err| cleanup(err) }
        end

        # Skip this loop if we can't do anything
        if Array(reads).empty? || writes.empty? || errors.any?
          sleep(1) if @sockets.empty?
          next
        end

        # Do the data transfers
        reads.each do |socket|
          begin
            @pairing[socket].proxy.transmit(writes, @pairing[socket].is_ws)
          rescue => error
            cleanup(socket, error)
          end
        end
      end
    end
  end

  def call(env)
    if WebSocket::Driver.websocket?(env) && same_origin_as_host?(env)
      if env['REQUEST_URI'] =~ %r{^/ws/notifications} && ::Settings.server.asynchronous_notifications
        ActionCable.server.call(env)
      else
        exp = %r{^/ws/console/([a-zA-Z0-9]+)/?$}.match(env['REQUEST_URI'])
        return not_found if exp.nil?
        init_proxy(env, exp[1])
      end

      [-1, {}, []]
    else
      logger.info("Invalid websocket request from: #{env['REMOTE_ADDR']}")
      not_found
    end
  end

  def healthy?
    %w(run sleep).include?(@transmitter.status)
  end

  private

  def init_proxy(env, url)
    console = SystemConsole.find_by!(:url_secret => url)
    proxy = WebsocketProxy.new(env, console, logger)
    return proxy.cleanup if proxy.error
    logger.info("Starting websocket proxy for VM #{console.vm_id}")
    proxy.start

    # Release the connection because one SPICE console can open multiple TCP connections
    ActiveRecord::Base.connection_pool.release_connection

    # Get the descriptors and pass them to the worker thread
    ws, sock = proxy.descriptors
    @pairing.merge!(ws => Pairing.new(true, proxy), sock => Pairing.new(false, proxy))
    @sockets.push(ws, sock)
  end

  def cleanup(socket, error = nil)
    return unless @pairing.include?(socket)

    if error
      "#{error.class} for #{@pairing[socket].proxy.vm_id}: #{error.message}\n#{error.backtrace.join("\n")}"
    else
      logger.info("Closing websocket proxy for VM #{@pairing[socket].proxy.vm_id}")
    end

    @pairing[socket].proxy.cleanup
    @sockets.delete(socket)
    @pairing.delete(socket)
  end

  def not_found
    [404, {'Content-Type' => 'text/plain'}, ['Not found']]
  end

  # Primitive same-origin policy checking in production
  def same_origin_as_host?(env)
    proto = Rack::Request.new(env).ssl? ? 'https' : 'http'
    host = env['HTTP_X_FORWARDED_HOST'] ? env['HTTP_X_FORWARDED_HOST'].split(/,\s*/).first : env['HTTP_HOST']
    Rails.env.development? || env['HTTP_ORIGIN'] == "#{proto}://#{host}"
  end
end
