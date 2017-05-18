module MiqCockpitWsWorker::Authenticator
  def self.authenticate_for_host(token, host)
    user_obj = user_for_token(token)
    return {} unless user_obj

    # is it a container deployment
    creds = find_container_node_creds(user_obj, host)

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

  # TODO: Do we need more user based permissions checks?
  def find_container_node_creds(user_obj, host_or_ip)
    raise "Looking up container nodes requires a valid user" unless user_obj
    cdn_table = ContainerDeploymentNode.arel_table
    cond = cdn_table[:name].eq(host_or_ip).or(cdn_table[:address].eq host_or_ip)
    deployment = ContainerDeployment.joins(:container_deployment_nodes).find_by(cond)

    if deployment
      return deployment.ssh_auth ? deployment.ssh_auth : Authentication.new
    elsif ContainerNode.exists?(:name => host_or_ip)
      return Authentication.new
    end
  end

  def creds_for_vm(vm)
    return nil unless vm
    creds = vm.container_deployment.nil? ? nil : vm.container_deployment.ssh_auth
    creds = vm.respond_to?(:key_pairs) ? vm.key_pairs.first : nil unless creds
    creds ? creds : Authentication.new
  end

  def find_vm(host_or_ip)
    vms = Vm.find_all_by_mac_address_and_hostname_and_ipaddress(nil, nil, host_or_ip)
    vms = Vm.find_all_by_mac_address_and_hostname_and_ipaddress(nil, host_or_ip, nil) unless vms.length == 1
    vms.length == 1 ? vms[0] : nil
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

  module_function :find_container_node_creds, :creds_for_vm, :find_vm, :find_vm_creds, :user_for_token
end
