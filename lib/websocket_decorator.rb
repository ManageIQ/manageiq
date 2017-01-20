# This module adds WebSocket capabilities for TCP sockets by decorating them
#
# It redefines the socket's read_nonblock and write_nonblock methods to seamlessly
# en/decapsulate WebSocket frames before actually sending/receiving any data over
# the network connection. The redefinition was necessary to maintain compatibility
# with IO.select and other networking-related system calls.

module WebsocketDecorator
  class << self
    def decorate(socket, version)
      # Initialize a buffer for decoding WebSocket frames
      buffer = WebSocket::Frame::Incoming::Server.new(:version => version)

      socket.define_singleton_method(:read_nonblock) do |length|
        # Call the super method and write it to the buffer
        buffer << super(length)
        # Decode the buffer frame by frame
        out = []
        loop do
          # Fetch the next frame from the buffer
          chunk = buffer.next
          # Break the loop if the frame was nil
          break if chunk.nil?
          # Append the decoded chunk to the output
          out << chunk.data
        end
        out.join('')
      end

      socket.define_singleton_method(:write_nonblock) do |data|
        # Build a WebSocket binary frame from the data to send
        frame = WebSocket::Frame::Outgoing::Server.new(:version => version, :data => data, :type => :binary)
        # Send out the frame using the super method
        super(frame.to_s)
      end

      socket
    end
  end
end
