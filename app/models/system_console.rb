class SystemConsole < ApplicationRecord
  belongs_to :vm
  belongs_to :user

  default_value_for :opened, false

  validates :url_secret, :uniqueness => true

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
    self.cleanup_proxy_processes
  end

  def self.allocate_port
    port_range_start = ::Settings.server.proxy_port.try(:start) || 6000
    port_range_end   = ::Settings.server.proxy_port.try(:end) || 7000

    used_ports = SystemConsole.where.not(:proxy_pid => nil).where(:host_name => local_address).order(:port).pluck(:port)

    (port_range_start..port_range_end).each do |port_number|
      return port_number if used_ports[0].nil? || used_ports[0] > port_number
      used_ports.shift if used_ports[0] == port_number
    end
    nil
  end

  def self.local_address
    MiqServer.my_server.ipaddress.blank? ? local_address_fallback : MiqServer.my_server.ipaddress
    #'10.40.5.140'
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

    command = '/usr/bin/socat', "TCP-LISTEN:#{local_port},fork", "TCP:#{remote_address}:#{remote_port}"
    _log.info("Running socat proxy command: #{command.join(' ')}")

    pid = spawn(*command)
    Process.detach(pid)

    return [local_address, local_port, pid]
  end

  def self.kill_proxy_process(pid)
    system('/usr/bin/kill', pid)
  end

  def self.cleanup_proxy_processes
    SystemConsole.where.not(:proxy_pid => nil).
      where( :host_name    => local_address) do |console|
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
end
