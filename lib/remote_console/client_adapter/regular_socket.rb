module RemoteConsole
  module ClientAdapter
    class RegularSocket < Base
      def fetch(length)
        yield(@sock.recv_nonblock(length))
      end

      def issue(data)
        @sock.write(data)
      end
    end
  end
end
