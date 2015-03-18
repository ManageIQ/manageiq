class WsProxy
  attr_accessor :host, :host_port, :password, :timeout, :idle_timeout, :ssl_target, :encrypt
  attr_reader :proxy_port

  PORT_RANGE = 5900..5999
  DEFAULT_CERT_FILE = 'certs/server.cer'
  DEFAULT_KEY_FILE  = 'certs/server.cer.key'

  def initialize(attributes)
    # setup all attributes.
    defaults.merge(attributes).each do |k, v|
      send("#{k}=", v) if self.respond_to?("#{k}=")
    end
  end

  def self.start(attributes)
    proxy = WsProxy.new(attributes)
    proxy.start_proxy
  end

  def start_proxy
    @proxy_port = nil
    (PORT_RANGE).each do |port|
      result = try_run_proxy(port)

      if result.failure?
        next if result.exit_status == 1 && result.error =~ /socket.error: \[Errno 98\] Address already in use/

        Rails.logger.error("error running websocket proxy: '#{result.command_line}' " \
                           "returned #{result.exit_status}, stderr: #{result.error}, stdout: #{result.output}")
        return nil
      end

      @proxy_port = port
      break
    end

    if @proxy_port.nil?
      Rails.logger.error("error running websocket proxy: 'No TCP ports available'")
      return nil
    end
    {:host => host, :port => host_port, :password => password, :proxy_port => proxy_port, :encrypt => encrypt}
  end

  private

  def file_or_default(config_path, default)
    file_requested = vmdb_config.fetch_path(:server, *config_path)
    if file_requested.present?
      file_requested = File.join(Rails.root, cert_file_requested)
      return file_requested if File.file?(file_requested)
    end
    default
  end

  def common_run_options
    @common_run_options ||= (
      run_options = {
        :daemon        => nil,
        :idle_timeout= => idle_timeout,
        :timeout=      => timeout,
      }
      run_options[:'ssl-target'] = nil if ssl_target

      if encrypt
        run_options[:cert] = file_or_default([:server, :websocket, :cert], DEFAULT_CERT_FILE)
        run_options[:key]  = file_or_default([:server, :websocket, :key],  DEFAULT_KEY_FILE)
      end

      run_options
    )
  end

  def try_run_proxy(port)
    run_options = common_run_options.update(nil => [port, "#{host}:#{host_port}"])
    AwesomeSpawn.run(ws_proxy, :params => run_options)
  end

  def vmdb_config
    @vmdb_config ||= VMDB::Config.new("vmdb").config
  end

  def ws_proxy
    "#{Rails.root}/extras/noVNC/websockify/websocketproxy.py"
  end

  def defaults
    {
      :timeout      => 120,
      :idle_timeout => 120,
      :host_port    => 5900,
      :host         => "0.0.0.0",
    }
  end
end
