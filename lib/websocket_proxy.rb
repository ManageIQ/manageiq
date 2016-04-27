class WebsocketProxy
  attr_reader :env, :url, :error

  def initialize(env, console)
    @env = env
    @id = SecureRandom.uuid
    @console = console

    secure = Rack::Request.new(env).ssl?
    scheme = secure ? 'wss:' : 'ws:'
    @url = scheme + '//' + env['HTTP_HOST'] + env['REQUEST_URI']
    @driver = WebSocket::Driver.rack(self, :protocols => %w(binary))

    begin
      # Hijack the socket from the Rack middleware
      @ws = env['rack.hijack'].call
      # Set up the socket client for the proxy
      @sock = TCPSocket.open(@console.host_name, @console.port)
      init_ssl if @console.ssl
    rescue
      @error = true
    end

    @driver.on(:open) { @console.update(:opened => true) }

    @driver.on(:message) do |msg|
      @ssl ? @ssl.syswrite(msg.data.pack('C*')) : @sock.write(msg.data.pack('C*'))
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
    else
      data = @ssl ? @ssl.sysread(64.kilobytes) : @sock.recv_nonblock(64.kilobytes)
      @driver.binary(data)
    end
  end

  def cleanup
    @console.destroy unless @console.destroyed?
    @sock.close if @sock && !@sock.closed?
    @ws.close if @ws && !@ws.closed?
  end

  def descriptors
    [@ws, @sock]
  end

  def write(string)
    @ws.write(string)
  end

  private

  def init_ssl
    context = OpenSSL::SSL::SSLContext.new
    context.cert = OpenSSL::X509::Certificate.new(File.open('certs/server.cer'))
    context.key = OpenSSL::PKey::RSA.new(File.open('certs/server.cer.key'))
    context.ssl_version = :SSLv23
    context.verify_depth = OpenSSL::SSL::VERIFY_NONE
    @ssl = OpenSSL::SSL::SSLSocket.new(@sock, context)
    @ssl.sync_close = true
    @ssl.connect
  end
end
