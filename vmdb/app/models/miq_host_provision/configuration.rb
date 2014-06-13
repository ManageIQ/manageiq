module MiqHostProvision::Configuration
  def set_network_information
    log_header = "MIQ(#{self.class.name}#set_network_information)"
    $log.info("#{log_header} Setting Network Information")
    self.destination.update_attributes!(:ipaddress => ip_address, :hostname => hostname)
    $log.info("#{log_header} Validating Host Credentials")

    # add the ssh host key even if there's an existing one from the prior OS install
    self.destination.authentication_check(:default, :remember_host => true)
    $log.info("#{log_header} Setting Network Information..complete -- ipaddress=[#{ip_address}], hostname=[#{hostname}]")
  end

  # TODO: Subclass
  def set_maintenance_mode_vmware
    log_header = "MIQ(#{self.class.name}#set_maintenance_mode_vmware)"
    self.destination.with_provider_object(:connection_source => self.host) do |vim_host|
      if vim_host.inMaintenanceMode?
        $log.info "#{log_header} Host is already Maintenance Mode"
      else
        $log.info "#{log_header} Putting host into Maintenance Mode..."
        vim_host.enterMaintenanceMode
        $log.info "#{log_header} Putting host into Maintenance Mode...complete"
      end
    end
  end

  def set_maintenance_mode
    # TODO: Subclass
    if self.destination.is_vmware?
      set_maintenance_mode_vmware
    else
      $log.warn "MIQ(#{self.class.name}#set_maintenance_mode) VMM Vendor [#{self.destination.vmm_vendor}] is not supported"
    end
  end

  # TODO: Subclass
  def add_storage_vmware
    log_header = "MIQ(#{self.class.name}#add_storage_vmware)"

    if self.destination.ext_management_system.nil?
      $log.error "#{log_header} Host has no External Management System"
      return
    end

    self.destination.with_provider_object do |vim_host|
      vim_dss = vim_host.datastoreSystem
      self.storages_to_attach.each do |storage|
        case storage.store_type
        when 'NFS'
          $log.info "#{log_header} Adding datastore: [#{storage.name}]"
          vim_dss.addNasDatastoreByName(storage.name)
          $log.info "#{log_header} Adding datastore: [#{storage.name}]...Complete"
        else
          $log.warn "#{log_header} Storage Type [#{storage.store_type}] is not supported"
        end
      end
    end
  end

  def add_storage
    # TODO: Subclass
    if self.destination.is_vmware?
      add_storage_vmware
    else
      $log.warn "MIQ(#{self.class.name}#add_storage) VMM Vendor [#{self.destination.vmm_vendor}] is not supported"
    end
  end

end
