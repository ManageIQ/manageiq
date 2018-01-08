class WebsocketRight
  def initialize(socket, model)
    @sock = socket
    @model = model
  end

  def fetch(*)
    raise NotImplementedError, 'This should be defined in a subclass'
  end

  def issue(*)
    raise NotImplementedError, 'This should be defined in a subclass'
  end
end
