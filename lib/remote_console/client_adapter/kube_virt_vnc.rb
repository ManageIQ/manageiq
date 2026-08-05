require "websocket/driver"

module RemoteConsole
  module ClientAdapter
    class KubeVirtVnc < SSLSocket
      attr_accessor :url

      def initialize(record, socket)
        super

        @url = @record.url

        @driver = WebSocket::Driver.client(
          self,
          :protocols => %w[plain.kubevirt.io]
        )

        @driver.set_header(
          "Authorization",
          "Bearer #{bearer_token}"
        )

        @driver.on(:close) { socket.close unless socket.closed? }

        @driver.start
      end

      def fetch(length)
        @driver.on(:message) { |msg| yield(msg.data) } if @driver.listeners(:message).empty?

        data = @ssl.send(:sysread_nonblock, length, :exception => false)
        @driver.parse(data) if data != :wait_readable
      end

      def issue(data)
        @driver.binary(data)
      end

      def write(data)
        @ssl.syswrite(data)
      end

      private

      def bearer_token
        @record.vm.ext_management_system.authentication_token("bearer")
      end

      def setup_ssl
        context = OpenSSL::SSL::SSLContext.new
        context.ssl_version = :SSLv23
        context.verify_mode = OpenSSL::SSL::VERIFY_NONE

        ssl = OpenSSL::SSL::SSLSocket.new(@sock, context)
        ssl.sync_close = true
        ssl.hostname = @record.host_name if ssl.respond_to?(:hostname=)

        ssl
      end
    end
  end
end
