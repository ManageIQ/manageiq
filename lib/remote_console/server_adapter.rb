module RemoteConsole
  module ServerAdapter
    def self.new(record, env, sock)
      if record.protocol.end_with?('uint8utf8')
        WebsocketUint8Utf8.new(env, sock)
      else
        WebsocketBinary.new(env, sock)
      end
    end
  end
end
