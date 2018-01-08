class WebsocketSocket < WebsocketRight
  def fetch(length)
    yield(@sock.recv_nonblock(length))
  end

  def issue(data)
    @sock.write(data)
  end
end
