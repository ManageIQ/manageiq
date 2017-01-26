module ManageIQ::Providers::Openstack::CloudManager::Provision::Cloning
  def do_clone_task_check(clone_task_ref)
    manager = source.ext_management_system.try(:parent_manager) || source.ext_management_system
    manager.with_provider_connection do |openstack|
      instance = openstack.handled_list(:servers).detect { |s| s.id == clone_task_ref }
      status   = instance.state.downcase.to_sym

      return true if status == :active
      return false, status
    end
  end

  def prepare_for_clone_task
    clone_options = super

    clone_options[:name]              = dest_name
    clone_options[:image_ref]         = source.ems_ref
    clone_options[:flavor_ref]        = instance_type.ems_ref
    clone_options[:availability_zone] = nil if dest_availability_zone.kind_of?(ManageIQ::Providers::Openstack::CloudManager::AvailabilityZoneNull)
    clone_options[:security_groups]   = security_groups.collect(&:ems_ref)
    clone_options[:nics]              = configure_network_adapters unless configure_network_adapters.blank?

    clone_options[:block_device_mapping_v2] = configure_volumes unless configure_volumes.blank?

    clone_options
  end

  def log_clone_options(clone_options)
    _log.info("Provisioning [#{source.name}] to [#{clone_options[:name]}]")
    _log.info("Source Image:                    [#{clone_options[:image_ref]}]")
    _log.info("Destination Availability Zone:   [#{clone_options[:availability_zone]}]")
    _log.info("Flavor:                          [#{clone_options[:flavor_ref]}]")
    _log.info("Guest Access Key Pair:           [#{clone_options[:key_name]}]")
    _log.info("Security Group:                  [#{clone_options[:security_groups]}]")
    _log.info("Network:                         [#{clone_options[:nics]}]")

    dumpObj(clone_options, "#{_log.prefix} Clone Options: ", $log, :info)
    dumpObj(options, "#{_log.prefix} Prov Options:  ", $log, :info, :protected => {:path => workflow_class.encrypted_options_field_regs})
  end

  def start_clone(clone_options)
    connection_options = {:tenant_name => options[:cloud_tenant][1]} if options[:cloud_tenant].kind_of? Array
    # If basing a new vm on an snapshot or volume, there's no image so remove it
    if source.class <= CloudVolume || source.class <= CloudVolumeSnapshot
      clone_options.delete :image_ref
    end
    # try to navigate up from the storage manager to the cloud manager if there is one
    manager = source.ext_management_system.try(:parent_manager) || source.ext_management_system
    manager.with_provider_connection(connection_options) do |openstack|
      instance = openstack.servers.create(clone_options)
      return instance.id
    end
  end
end
