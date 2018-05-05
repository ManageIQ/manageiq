class WebsocketWebmksUint8utf8 < WebsocketSSLSocket
  attr_accessor :url

  def initialize(socket, model)
    super(socket, model)
    @url = URI::Generic.build(:scheme => 'wss',
                              :host   => @model.host_name,
                              :port   => @model.port,
                              :path   => @model.url).to_s

    @driver = WebSocket::Driver.client(self, :protocols => ['uint8utf8'])
    @driver.on(:close) { socket.close unless socket.closed? }
    @driver.start
  end

  def fetch(length)
    # WebSocket::Driver requires an event handler that should be registered only once
    @driver.on(:message) { |msg| yield(msg.data) } if @driver.listeners(:message).length.zero?

    data = @ssl.sysread(length)
    @driver.parse(data)
  end

  def issue(data)
    @driver.frame(data)
  end

  def write(data)
    @ssl.syswrite(data)
  end
end
