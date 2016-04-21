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

  def check_ip_addr_available(vm)
    ip_list = vm.ipaddresses
    @handle.log(:info, "Current Power State #{vm.power_state}")
    @handle.log(:info, "IP addresses for VM #{ip_list}")

    if ip_list.empty?
      vm.refresh
      @handle.root['ae_result'] = 'retry'
      @handle.root['ae_retry_limit'] = 1.minute
    else
      @handle.root['ae_result'] = 'ok'
    end
  end

  def vm_not_found
    @handle.root['ae_result'] = 'error'
    @handle.log(:error, "VM not found")
  end
end

if __FILE__ == $PROGRAM_NAME
  WaitForIP.new().main
end
