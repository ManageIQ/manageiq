class SystemConsole < ApplicationRecord
  belongs_to :vm
  belongs_to :user

  default_value_for :opened, false

  validates :url_secret, :uniqueness_when_changed => true

  def connection_params
    {
      :url    => "ws/console/#{url_secret}",
      :secret => secret,
      :proto  => protocol
    }
  end

  def destroy_or_mark
    if proxy_pid.nil?
      destroy
      return
    end
    update(:proxy_status => 'websocket_closed')
    SystemConsole.cleanup_proxy_processes
  end

  def self.allocate_port
    port_range_start = ::Settings.server.console_proxy_port.start
    port_range_end   = ::Settings.server.console_proxy_port.end

    used_ports = SystemConsole.where.not(:proxy_pid => nil).where(:host_name => local_address).order(:port).pluck(:port).uniq

    (port_range_start..port_range_end).each do |port_number|
      return port_number if used_ports[0].nil? || used_ports[0] > port_number
      used_ports.shift if used_ports[0] == port_number
    end
    nil
  end

  def self.local_address
    MiqServer.my_server.ipaddress.blank? ? local_address_fallback : MiqServer.my_server.ipaddress
  end

  def self.local_address_fallback
    require 'socket'
    Socket.ip_address_list.collect(&:ip_address).reject { |address| address == '127.0.0.1' }.first
  end

  def self.launch_proxy(remote_address, remote_port)
    local_port = allocate_port

    if local_port.nil?
      _log.error("No unused ports for proxy.")
      return nil
    end

    command = AwesomeSpawn::CommandLineBuilder.new.build("/usr/bin/socat", ["TCP-LISTEN:" + local_port + ",fork", "TCP:" + remote_address + ":" + remote_port])
    _log.info("Running socat proxy command: #{command}")
    pid = spawn(command)

    Process.detach(pid)

    return [local_address, local_port, pid]
  end

  def self.kill_proxy_process(pid)
    system('/usr/bin/kill', pid.to_s)
  end

  def self.cleanup_proxy_processes
    SystemConsole.where.not(:proxy_pid => nil).where(:host_name  => local_address).each do |console|
      next unless %w(websocket_closed ticket_invalid).include?(console.proxy_status)
      kill_proxy_process(console.proxy_pid)
      console.destroy
    end
  end

  def self.force_vm_invalid_token(vm_id)
    SystemConsole.where(:vm_id => vm_id).each do |console|
      if console.proxy_pid.nil?
        console.destroy
        next
      else
        console.update(:vm_id => :nil, :proxy_status => 'ticket_invalid')
      end
    end
  end

  def self.is_local?(originating_server)
    MiqServer.my_server.id == originating_server.to_i
  end

  def self.launch_proxy_if_not_local(console_args, originating_server, host_address, host_port)
    _log.info("Originating server: #{originating_server}, local server: #{MiqServer.my_server.id}")

    if ::Settings.server.console_proxy_disabled || SystemConsole.is_local?(originating_server)
      console_args.update(
        :host_name  => host_address,
        :port       => host_port,
      )
    else
      SystemConsole.cleanup_proxy_processes
      proxy_address, proxy_port, proxy_pid = SystemConsole.launch_proxy(host_address, host_port)
      return nil if proxy_address.nil?

      _log.info("Proxy server started: #{proxy_address}:#{proxy_port} <--> #{host_address}:#{host_port}")
      _log.info("Proxy process PID: #{proxy_pid}")

      console_args.update(
        :host_name    => proxy_address,
        :port         => proxy_port,
        :proxy_status => 'proxy_running',
        :proxy_pid    => proxy_pid
      )
    end

    SystemConsole.create!(console_args).connection_params
  end
end
