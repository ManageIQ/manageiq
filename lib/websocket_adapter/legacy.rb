module WebsocketAdapter
  class Legacy < Standard
    def fetch(length)
      @driver.on(:message) { |msg| yield(msg.data) } if @driver.listeners(:message).length.zero?

      data = @sock.read_nonblock(length)
      @driver.parse(data)
    end

    def issue(data)
      @driver.frame(data)
    end

    private

    def protocol
      'uint8utf8'.freeze
    end
  end
end
