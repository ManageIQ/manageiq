module VmOrTemplate::VmwareShared
  include_concern 'RefreshOnScan'

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

    connection.getVimVmByMor(mor)
  end

  def provider_object_release(handle)
    handle.release if handle rescue nil
  end
end
