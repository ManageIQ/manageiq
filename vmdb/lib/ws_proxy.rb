class WsProxy
  attr_accessor :host, :host_port, :password, :timeout, :idle_timeout, :ssl_target, :encrypt
  attr_reader :proxy_port

  PORT_RANGE = 5900..5999

  def initialize(attributes)
    # setup all attributes.
    defaults.merge(attributes).each do |k, v|
      self.send("#{k}=", v) if self.respond_to?("#{k}=")
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

  def common_run_options
    @common_run_options ||= (
      run_options = {
        :daemon        => nil,
        :idle_timeout= => idle_timeout,
        :timeout=      => timeout,
      }
      run_options[:'ssl-target'] = nil if ssl_target

      if vmdb_config.fetch_path(:server, :websocket_encrypt)
        cert_file = File.join(Rails.root, vmdb_config.fetch_path(:server, :websocket_cert))
        key_file  = File.join(Rails.root, vmdb_config.fetch_path(:server, :websocket_key))

        run_options[:cert] = cert_file if File.file?(cert_file)
        run_options[:key]  = key_file  if File.file?(key_file)
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
