class WebsocketProxy
  attr_reader :env, :url, :error

  def initialize(env, console, logger)
    @env = env
    @id = SecureRandom.uuid
    @console = console
    @logger = logger
    @protocol = 'binary'

    secure = Rack::Request.new(env).ssl?
    scheme = secure ? 'wss:' : 'ws:'
    @url = scheme + '//' + env['HTTP_HOST'] + env['REQUEST_URI']

    # VMware vCloud WebMKS SDK (console access) grabs 'binary' if offered, but then fails because in fact it's not
    # able to use it :) We workaround this by only forcing the 'uint8utf8' protocol which actually works.
    @protocol = 'uint8utf8' if console.protocol.to_s.end_with?('uint8utf8')

    @driver = WebSocket::Driver.rack(self, :protocols => [@protocol])

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
                when 'webmks-uint8utf8'
                  WebsocketWebmksUint8utf8
                end
      @right = adapter.new(@sock, @console)
    rescue => ex
      @logger.error(ex)
      @error = true
    end

    @driver.on(:open) { @console.update(:opened => true) }

    # TODO: Move binary <-> string interpretation into client class, don't do it here (reusability).
    if binary?
      @driver.on(:message) { |msg| @right.issue(msg.data.pack('C*')) }
    else
      @driver.on(:message) { |msg| @right.issue(msg.data) }
    end

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
    elsif binary?
      @right.fetch(64.kilobytes) do |data|
        @driver.binary(data)
      end
    else
      @right.fetch(64.kilobytes) do |data|
        @driver.frame(data)
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

  def binary?
    @protocol == 'binary'
  end
end
