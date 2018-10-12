module WebsocketAdapter
  def self.new(record, env, sock)
    if record.protocol.end_with?('uint8utf8')
      WebsocketAdapter::Legacy.new(env, sock)
    else
      WebsocketAdapter::Standard.new(env, sock)
    end
  end
end
