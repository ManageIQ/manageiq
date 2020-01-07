module MiqCockpitWsWorker::Authenticator
  def self.authenticate_for_host(token, host)
    user_obj = user_for_token(token)
    return {} unless user_obj

    # Is it a VM
    creds = find_vm_creds(user_obj, host) if creds.nil?

    {
      :valid  => true,
      :known  => !creds.nil?,
      :key    => creds.try(:auth_key),
      :userid => creds.try(:userid)
    }
  end

  def self.ssh_command
    MiqCockpit::WS::COCKPIT_SSH_PATH
  end

  def creds_for_vm(vm)
    return nil unless vm

    creds = vm.key_pairs.first if vm.respond_to?(:key_pairs)
    creds || Authentication.new
  end

  def find_vm(host_or_ip)
    vms = Vm.find_all_by_mac_address_and_hostname_and_ipaddress(nil, nil, host_or_ip)
    vms = Vm.find_all_by_mac_address_and_hostname_and_ipaddress(nil, host_or_ip, nil) unless vms.length == 1
    vms[0] if vms.length == 1
  end

  def find_vm_creds(user_obj, host_or_ip)
    raise "Looking up VMs requires a valid user" unless user_obj
    vm = find_vm(host_or_ip)
    creds_for_vm(vm)
  end

  def user_for_token(token)
    mgr = Api::Environment.user_token_service.token_mgr('api')
    if mgr.token_valid?(token)
      userid = mgr.token_get_info(token, :userid)
      user_obj = User.find_by(:userid => userid)
    end
    user_obj
  end

  module_function :creds_for_vm, :find_vm, :find_vm_creds, :user_for_token
end
