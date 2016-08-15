#
# Description: Wait for the IP address to be available on the VM
# For VMWare for this to work the VMWare tools should be installed
# on the newly provisioned vm's

class WaitForIP
  def initialize(handle = $evm)
    @handle = handle
  end

  def main
    vm = @handle.root["miq_provision"].try(:destination)
    vm ||= @handle.root["vm"]
    vm ? check_ip_addr_available(vm) : vm_not_found
  end

  require 'timeout'
  require 'socket'
  def ssh_port_open?(host, port, timeout = 180, sleep_period = 5)
    Timeout.timeout(timeout) do
      begin
        s = TCPSocket.new(host, port)
        s.close
        return true
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
        sleep(sleep_period)
        retry
      end
    end
  rescue Timeout::Error
    return false
    # end
  end

  def check_ip_addr_available(vm, port = 22, timeout = 600, sleep_period = 10)
    ip_list = vm.ipaddresses
    @handle.log(:info, "Current Power State #{vm.power_state}")
    @handle.log(:info, "IP addresses for VM #{ip_list}")

    if ip_list.empty?
      vm.refresh
      @handle.root['ae_result'] = 'retry'
      @handle.root['ae_retry_limit'] = 1.minute
    elsif ssh_port_open?(ip_list.first, port, timeout, sleep_period)
      @handle.root['ae_result'] = 'ok'
    end
  end

  def vm_not_found
    @handle.root['ae_result'] = 'error'
    @handle.log(:error, "VM not found")
  end
end

if __FILE__ == $PROGRAM_NAME
  WaitForIP.new.main
end
