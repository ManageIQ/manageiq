module MiqHostProvision::Configuration
  def set_network_information
    _log.info("Setting Network Information")
    self.destination.update_attributes!(:ipaddress => ip_address, :hostname => hostname)
    _log.info("Validating Host Credentials")

    # add the ssh host key even if there's an existing one from the prior OS install
    self.destination.authentication_check(:default, :remember_host => true)
    _log.info("Setting Network Information..complete -- ipaddress=[#{ip_address}], hostname=[#{hostname}]")
  end

  # TODO: Subclass
  def set_maintenance_mode_vmware
    self.destination.with_provider_object(:connection_source => self.host) do |vim_host|
      if vim_host.inMaintenanceMode?
        _log.info "Host is already Maintenance Mode"
      else
        _log.info "Putting host into Maintenance Mode..."
        vim_host.enterMaintenanceMode
        _log.info "Putting host into Maintenance Mode...complete"
      end
    end
  end

  def set_maintenance_mode
    # TODO: Subclass
    if self.destination.is_vmware?
      set_maintenance_mode_vmware
    else
      _log.warn "VMM Vendor [#{self.destination.vmm_vendor}] is not supported"
    end
  end

  # TODO: Subclass
  def add_storage_vmware
    if self.destination.ext_management_system.nil?
      _log.error "Host has no External Management System"
      return
    end

    self.destination.with_provider_object do |vim_host|
      vim_dss = vim_host.datastoreSystem
      self.storages_to_attach.each do |storage|
        case storage.store_type
        when 'NFS'
          _log.info "Adding datastore: [#{storage.name}]"
          vim_dss.addNasDatastoreByName(storage.name)
          _log.info "Adding datastore: [#{storage.name}]...Complete"
        else
          _log.warn "Storage Type [#{storage.store_type}] is not supported"
        end
      end
    end
  end

  def add_storage
    # TODO: Subclass
    if self.destination.is_vmware?
      add_storage_vmware
    else
      _log.warn "VMM Vendor [#{self.destination.vmm_vendor}] is not supported"
    end
  end

end
