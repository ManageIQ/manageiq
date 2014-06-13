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
      self.options["dest_#{key}".to_sym] = [object.id, object.name]
    end
  end

  private

  def manual_placement
    desired = {}
    cluster_id = get_option(:placement_cluster_name)
    raise MiqException::MiqProvisionError, "Destination cluster not provided" if cluster_id.blank?
    desired[:cluster] = EmsCluster.find_by_id(cluster_id)

    datastore_id = get_option(:placement_ds_name)
    desired[:storage] = Storage.find_by_id(datastore_id)

    host_id = get_option(:placement_host_name)
    desired[:host] = Host.find_by_id(host_id)

    desired
  end

  def automatic_placement
    self.get_placement_via_automate
  end
end
