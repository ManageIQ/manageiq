class WebsocketSSLSocket < WebsocketRight
  def initialize(socket, model)
    super(socket, model)

    context = OpenSSL::SSL::SSLContext.new
    context.cert = OpenSSL::X509::Certificate.new(File.open('certs/server.cer'))
    context.key = OpenSSL::PKey::RSA.new(File.open('certs/server.cer.key'))
    context.ssl_version = :SSLv23
    context.verify_depth = OpenSSL::SSL::VERIFY_NONE
    @ssl = OpenSSL::SSL::SSLSocket.new(@sock, context)
    @ssl.sync_close = true
    @ssl.connect
  end

  def fetch(length)
    yield(@ssl.sysread(length))
  end

  def issue(data)
    @ssl.syswrite(data)
  end
end
