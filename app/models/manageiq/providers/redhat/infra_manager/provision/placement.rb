module ManageIQ::Providers::Redhat::InfraManager::Provision::Placement
  protected

  def placement
    desired = get_option(:placement_auto) ? automatic_placement : manual_placement

    raise MiqException::MiqProvisionError, "Unable to find a suitable cluster" if desired[:cluster].nil?

    [:cluster, :host, :storage].each do |key|
      object = desired[key]
      next if object.nil?
      _log.info("Using #{key.to_s.titleize} Id: [#{object.id}], Name: [#{object.name}]")
      options["dest_#{key}".to_sym] = [object.id, object.name]
    end
  end

  private

  def manual_placement
    update_placement_info
  end

  def selected_placement_host
    Host.find_by(:id => get_option(:placement_host_name))
  end

  def selected_placement_ds
    Storage.find_by(:id => get_option(:placement_ds_name))
  end

  def selected_placement_cluster
    EmsCluster.find_by(:id => get_option(:placement_cluster_name)).tap do |cluster|
      raise MiqException::MiqProvisionError, 'Destination cluster not provided' unless cluster
    end
  end

  def automatic_placement
    update_placement_info(get_placement_via_automate)
  end

  def update_placement_info(result = {})
    result[:cluster] = selected_placement_cluster if result[:cluster].nil?
    result[:host]    = selected_placement_host    if result[:host].nil?
    result[:storage] = selected_placement_ds      if result[:storage].nil?
    result
  end
end
