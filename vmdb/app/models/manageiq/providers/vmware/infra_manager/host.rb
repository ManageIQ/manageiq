class ManageIQ::Providers::Vmware::InfraManager::Host < ::Host
  include VimConnectMixin

  def provider_object(connection)
    api_type = connection.about["apiType"]
    mor =
      case api_type
      when "VirtualCenter"
        # The ems_ref in the VMDB is from the vCenter perspective
        self.ems_ref
      when "HostAgent"
        # Since we are going directly to the host, it acts like a VC
        # Thus, there is only a single host in it
        # It has a MOR for itself, which is different from the vCenter MOR
        connection.hostSystemsByMor.keys.first
      else
        raise "Unknown connection API type '#{api_type}'"
      end

    connection.getVimHostByMor(mor)
  end

  def provider_object_release(handle)
    handle.release if handle rescue nil
  end


  def get_files_on_datastore(datastore)
    self.with_provider_connection do |vim|
      begin
        vimDs = vim.getVimDataStore(datastore.name)
        return vimDs.dsFolderFileList
      rescue Handsoap::Fault, StandardError, TimeoutError, DRb::DRbConnError => err
        _log.log_backtrace(err)
        raise MiqException::MiqStorageError, "Error communicating with Host: [#{self.name}]"
      ensure
        vimDs.release if vimDs rescue nil
      end
    end

    return nil
  end

  def refresh_files_on_datastore(datastore)
    hashes = ManageIQ::Providers::Vmware::InfraManager::RefreshParser.datastore_file_inv_to_hashes(get_files_on_datastore(datastore), datastore.vm_ids_by_path)
    EmsRefresh.save_storage_files_inventory(datastore, hashes)
  end

  def reserve_next_available_vnc_port
    port_start = self.ext_management_system.try(:host_default_vnc_port_start).try(:to_i) || 5900
    port_end   = self.ext_management_system.try(:host_default_vnc_port_end).try(:to_i)   || 5999

    self.lock do
      port = self.next_available_vnc_port
      port = port_start unless port.in?(port_start..port_end)

      next_port = (port == port_end ? port_start : port + 1)
      self.update_attributes(:next_available_vnc_port => next_port)

      port
    end
  end
end
