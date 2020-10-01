module RemoteConsole
  module ClientAdapter
    class SSLSocket < Base
      def initialize(record, socket)
        super(record, socket)

        @ssl = setup_ssl
        @ssl.connect
      end

      def fetch(length)
        data = @ssl.send(:sysread_nonblock, length, :exception => false)
        # Give a second chance for the read if it's blocking after a 1s timeout
        if data == :wait_readable
          IO.select([@ssl], [], [], 1)
          data = @ssl.send(:sysread_nonblock, length)
        end

        yield(data)
      end

      def issue(data)
        @ssl.syswrite(data)
      end

      private

      def setup_ssl
        context = OpenSSL::SSL::SSLContext.new
        context.cert = OpenSSL::X509::Certificate.new(File.open('certs/server.cer'))
        context.key = OpenSSL::PKey::RSA.new(File.open('certs/server.cer.key'))
        context.ssl_version = :SSLv23
        context.verify_depth = OpenSSL::SSL::VERIFY_NONE

        ssl = OpenSSL::SSL::SSLSocket.new(@sock, context)
        ssl.sync_close = true

        ssl
      end
    end
  end
end
