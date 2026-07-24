require 'websocket/driver'

module RemoteConsole
  module ClientAdapter
    class KubeExec < SSLSocket
      attr_accessor :url

      STDIN_CHANNEL  = 0
      STDOUT_CHANNEL = 1
      STDERR_CHANNEL = 2
      ERROR_CHANNEL  = 3
      RESIZE_CHANNEL = 4

      def initialize(record, socket)
        super
        @url = URI::Generic.build(:scheme => 'wss',
                                  :host   => @record.host_name,
                                  :port   => @record.port,
                                  :path   => path,
                                  :query  => query).to_s
        @driver = WebSocket::Driver.client(self, :protocols => %w[v4.channel.k8s.io channel.k8s.io])
        @driver.set_header('Authorization', "Bearer #{bearer_token}")
        @driver.on(:close) { socket.close unless socket.closed? }
        @driver.start
      end

      def fetch(length)
        if @driver.listeners(:message).empty?
          @driver.on(:message) do |msg|
            channel = msg.data.getbyte(0)
            payload = msg.data.byteslice(1..)
            yield(payload) if [STDOUT_CHANNEL, STDERR_CHANNEL].include?(channel)
          end
        end
        data = @ssl.send(:sysread_nonblock, length, :exception => false)
        @driver.parse(data) if data != :wait_readable
      end

      def issue(data)
        @driver.binary(STDIN_CHANNEL.chr + data)
      end

      def write(data)
        @ssl.syswrite(data)
      end

      private

      def bearer_token
        container.container_group.ext_management_system.authentication_token('bearer')
      end

      def container
        @record.container
      end

      def path
        "/api/v1/namespaces/#{container.container_group.container_project.name}/pods/#{container.container_group.name}/exec"
      end

      def query
        URI.encode_www_form(
          :command   => '/bin/sh',
          :container => container.name,
          :stdin     => true,
          :stdout    => true,
          :stderr    => true,
          :tty       => true
        )
      end

      private

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
