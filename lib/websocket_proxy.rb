class WebsocketProxy
  attr_reader :env, :url, :error

  def initialize(env, console, logger)
    @env = env
    @id = SecureRandom.uuid
    @console = console
    @logger = logger

    secure = Rack::Request.new(env).ssl?
    scheme = secure ? 'wss:' : 'ws:'
    @url = scheme + '//' + env['HTTP_HOST'] + env['REQUEST_URI']
    @driver = WebSocket::Driver.rack(self, :protocols => %w(binary))

    begin
      # Hijack the socket from the Rack middleware
      @ws = env['rack.hijack'].call
      # Set up the socket client for the proxy
      @sock = TCPSocket.open(@console.host_name, @console.port)
      adapter = case @console.protocol
                when 'vnc'
                  WebsocketSocket
                when 'spice'
                  @console.ssl ? WebsocketSSLSocket : WebsocketSocket
                when 'webmks'
                  WebsocketWebmks
                end
      @right = adapter.new(@sock, @console)
    rescue => ex
      @logger.error(ex)
      @error = true
    end

    @driver.on(:open) { @console.update(:opened => true) }

    @driver.on(:message) { |msg| @right.issue(msg.data.pack('C*')) }

    @driver.on(:close) { cleanup }
  end

  def start
    @driver.start
  end

  def transmit(sockets, is_ws)
    # Do not read when the other end is not ready for writing
    return unless is_ws ? sockets.include?(@ws) : sockets.include?(@sock)

    if is_ws
      data = @ws.recv_nonblock(64.kilobytes)
      @driver.parse(data)
    else
      @right.fetch(64.kilobytes) do |data|
        @driver.binary(data)
      end
    end
  end

  def cleanup
    # FIXME:
    # if @console.proxy_pid.present?
    #   need to kill proxy process on the ems_operations appliance...
    @console.destroy_or_mark unless @console.destroyed?
    @sock.close if @sock && !@sock.closed?
    @ws.close if @ws && !@ws.closed?
  end

  def descriptors
    [@ws, @sock]
  end

  def write(string)
    @ws.write(string)
  end

  def vm_id
    @console ? @console.vm_id : 'unknown'
  end
end
