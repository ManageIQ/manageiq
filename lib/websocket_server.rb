class WebsocketServer
  attr_reader :logger

  def initialize(options = {})
    @logger = options.fetch(:logger, $websocket_log)
    @logger.info('Initializing websocket worker!')
    @proxy = SurroGate.new(@logger)
  end

  def call(env)
    driver = WebSocket::Handshake::Server.new(:protocols => %w(binary))
    driver.from_rack(env)
    task = parse_request(env, driver)

    case task
    when :error
      @logger.info("Invalid WebSocket request from: #{env['REMOTE_ADDR']}")
      return not_found
    when :cable
      @logger.info("Forwarding request to ActionCable from: #{env['REMOTE_ADDR']}")
      return ActionCable.server.call(env)
    else
      @logger.info("Remote console request from: #{env['REMOTE_ADDR']}")
      return init_proxy(env, task, driver)
    end
  end

  private

  def init_proxy(env, url_secret, handshake)
    # Retrieve the parameters of the console
    console = SystemConsole.find_by!(:url_secret => url_secret)
    # Release the DB connection
    ActiveRecord::Base.connection_pool.release_connection

    # Hijack the socket from the Rack middleware
    ws = env['rack.hijack'].call
    # Send back the handshake response
    ws.write_nonblock(handshake.to_s)
    # Decorate the socket for seamless WebSocket en/decapsulation
    ws = WebsocketDecorator.decorate(ws, handshake.version)
    # Set up the socket client for the proxy
    sock = TCPSocket.open(console.host_name, console.port)
    # Optionally swap the socket with an SSL-enabled one
    sock = init_ssl(sock) if console.ssl

    # Pass the sockets to SurroGate
    @proxy.push(sock, ws) do
      @logger.info("Closing connection between: #{ws} <-> #{sock}")
      console.destroy_or_mark unless console.destroyed?
    end

    # Return with an empty structure for Rack
    [-1, {}, []]
  rescue => ex
    # Log the error message
    @logger.error(ex.message)
    # Close both connections
    ws.close unless ws.nil?
    sock.close unless sock.nil?
    # Remove the DB record
    console.destroy_or_mark unless console.nil? || console.destroyed?
    return not_found
  end

  def init_ssl(socket)
    context = OpenSSL::SSL::SSLContext.new
    context.cert = OpenSSL::X509::Certificate.new(File.open('certs/server.cer'))
    context.key = OpenSSL::PKey::RSA.new(File.open('certs/server.cer.key'))
    context.ssl_version = :SSLv23
    context.verify_depth = OpenSSL::SSL::VERIFY_NONE
    sslsock = OpenSSL::SSL::SSLSocket.new(socket, context)
    sslsock.sync_close = true
    sslsock
  end

  def parse_request(env, driver)
    return :error unless driver.valid? && driver.finished? && same_origin_as_host?(env)
    return :cable if env['REQUEST_URI'] =~ %r{^/ws/notifications}
    exp = %r{^/ws/console/([a-zA-Z0-9]+)/?$}.match(env['REQUEST_URI'])
    exp.nil? ? :error : exp[1]
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
