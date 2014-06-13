module MiqProvisionVmware::Placement::NetApp

  def create_netapp_datastore
    log_header = "MIQ(#{self.class.name}.create_netapp_datastore)"

    ems     = self.source.ext_management_system
    host    = get_option(:placement_host_name)
    ds_host = Host.find_by_id(host)
    ds_name = get_option(:new_datastore_name)
    ds_datastore = ems.storages.detect {|s| s.name == ds_name}

    if ds_datastore.nil?
      host    = get_option(:placement_host_name)
      ds_host = Host.find_by_id(host)
      ds_controller     = get_option(:new_datastore_storage_controller)
      ds_aggregate_name = get_option(:new_datastore_aggregate)
      ds_size           = get_option(:new_datastore_size).to_i * 1024
      protocol          = get_option(:new_datastore_fs_type)
      thin_provision    = get_option(:new_datastore_thin_provision).to_s == "true"
      auto_grow         = get_option(:new_datastore_autogrow).to_s == "true"
      ds_grow_increment = get_option(:new_datastore_grow_increment)
      ds_max_size       = get_option(:new_datastore_max_size)
      $log.info "#{log_header} Creating NetApp datastore for host <#{ds_host.name}> on storage controller <#{ds_controller.inspect}> with settings Aggregate:<#{ds_aggregate_name.inspect}> Name:<#{ds_name.inspect}> Size:<#{ds_size.inspect}> Protocol:<#{protocol.inspect}> Thin:<#{thin_provision.inspect}> AutoGrow:<#{auto_grow.inspect}> GrowIncrement:<#{ds_grow_increment.inspect}> MaxSize:<#{ds_max_size.inspect}>"
      filer = NetAppFiler.find_by_name(ds_controller)
      filer.create_datastore(ds_host, ds_aggregate_name, ds_name, ds_size, protocol, thin_provision, auto_grow, ds_grow_increment, ds_max_size)
      $log.info "#{log_header} NetApp datastore creation completed for host <#{ds_host.name}> on storage controller <#{ds_controller.inspect}> with settings Aggregate:<#{ds_aggregate_name.inspect}> Name:<#{ds_name.inspect}> Size:<#{ds_size.inspect}> Protocol:<#{protocol.inspect}> Thin:<#{thin_provision.inspect}> AutoGrow:<#{auto_grow.inspect}> GrowIncrement:<#{ds_grow_increment.inspect}> MaxSize:<#{ds_max_size.inspect}>"
      $log.info "#{log_header} Queueing Refresh Host to identify new datastore"
      EmsRefresh.queue_refresh(ds_host)
    end

    return [ds_host, ds_datastore]
  end

end
