module MiqProvisionRedhat::Placement
  protected

  def placement
    log_header = "MIQ(#{self.class.name}.placement)"
    desired = get_option(:placement_auto) ? automatic_placement : manual_placement

    raise MiqException::MiqProvisionError, "Unable to find a suitable cluster" if desired[:cluster].nil?

    [:cluster, :host, :storage].each do |key|
      object = desired[key]
      next if object.nil?
      $log.info("#{log_header} Using #{key.to_s.titleize} Id: [#{object.id}], Name: [#{object.name}]")
      options["dest_#{key}".to_sym] = [object.id, object.name]
    end
  end

  private

  def manual_placement
    update_placement_info
  end

  def selected_placement_host
    Host.where(:id => get_option(:placement_host_name)).first
  end

  def selected_placement_ds
    Storage.where(:id => get_option(:placement_ds_name)).first
  end

  def selected_placement_cluster
    EmsCluster.where(:id => get_option(:placement_cluster_name)).first.tap do |cluster|
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
