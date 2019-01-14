module RemoteConsole
  module ServerAdapter
    def self.new(record, env, sock)
      if record.protocol.end_with?('uint8utf8')
        WebMKSLegacy.new(env, sock)
      else
        Websocket.new(env, sock)
      end
    end
  end
end
