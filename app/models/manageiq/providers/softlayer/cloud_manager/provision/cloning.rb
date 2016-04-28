module ManageIQ::Providers::Softlayer::CloudManager::Provision::Cloning
  def do_clone_task_check(clone_task_ref)
    source.with_provider_connection do |compute|
      instance = compute.servers.get(clone_task_ref)

      return true if instance.ready?
      return false, instance.state
    end
  end

  def find_cloud_network_in_vmdb(network_id = nil)
    return if network_id.nil?

    cloud_network = ManageIQ::Providers::Softlayer::NetworkManager::CloudNetwork.find(network_id)
    cloud_network.ems_ref.to_i
  end

  def prepare_for_clone_task
    clone_options = super
    ems = source.try(:ext_management_system)
    vlan_id = get_option(:cloud_network)
    # NOTE: Private vlan is represented in the provisioning form as a :cloud_subnet
    # (rendered as a same type so there's no need for a new specialized field)
    private_vlan_id = get_option(:cloud_subnet)

    # NOTE: Cloning might fail for some images due to missing base OS (in the image).
    # This information is not available via API, it's safe to use own images though.
    additional_options = {
      :flavor_id  => instance_type.name,
      :image_id   => source.uid_ems,
      :name       => dest_name,
      :domain     => get_option(:vm_domain),
      :datacenter => ems.provider_region,
      :vlan => find_cloud_network_in_vmdb(vlan_id),
      :private_vlan => find_cloud_network_in_vmdb(private_vlan_id),
    }

    clone_options.merge(additional_options)
  end

  def log_clone_options(clone_options)
    dumpObj(clone_options, "#{_log.prefix} Clone Options: ", $log, :info)
    dumpObj(options, "#{_log.prefix} Prov Options:  ", $log, :info, :protected => {:path => workflow_class.encrypted_options_field_regs})
  end

  def start_clone(clone_options)
    source.with_provider_connection do |compute|
      instance = compute.servers.create(clone_options)

      instance.id
    end
  end
end
