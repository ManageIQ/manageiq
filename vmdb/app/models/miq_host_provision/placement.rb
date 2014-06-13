module MiqHostProvision::Placement

  def placement_ems
    @placement_ems ||= ExtManagementSystem.find_by_id(get_option(:placement_ems_name))
  end

  def placement_cluster
    @placement_cluster ||= EmsCluster.find_by_id(get_option(:placement_cluster_name))
  end

  def placement_folder
    @placement_folder ||= EmsFolder.find_by_id(get_option(:placement_folder_name))
  end

  # TODO: Subclass
  def place_in_ems_vmware
    log_header = "MIQ(#{self.class.name}#place_in_ems_vmware)"

    ems_cluster = self.placement_cluster
    unless ems_cluster.nil?
      $log.info("#{log_header} Registering Host on Cluster: [#{ems_cluster.name}]")
      return ems_cluster.register_host(self.host)
    end

    ems_folder = self.placement_folder
    unless ems_folder.nil?
      $log.info("#{log_header} Registering Host on Folder: [#{ems_folder.name}]")
      return ems_folder.register_host(self.host)
    end
  end

  def place_in_ems
    log_header = "MIQ(#{self.class.name}#place_in_ems)"

    # TODO: Subclass
    if self.host.is_vmware?
      place_in_ems_vmware
    else
      $log.warn "#{log_header} VMM Vendor [#{self.host.vmm_vendor}] is not supported"
    end
  end

end
