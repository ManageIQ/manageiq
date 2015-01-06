module MiqProvisionMicrosoft::Placement
  protected

  def placement
    log_header = "MIQ(#{self.class.name}.placement)"
    desired    = manual_placement

    if desired[:host].nil? || desired[:storage].nil?
      raise MiqException::MiqProvisionError, "Unable to find a suitable environment"
    end

    [:host, :storage].each do |key|
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

  def update_placement_info(result = {})
    result[:host]    = selected_placement_host if result[:host].nil?
    result[:storage] = selected_placement_ds   if result[:storage].nil?
    result
  end

  def selected_placement_host
    Host.where(:id => get_option(:placement_host_name)).first
  end

  def selected_placement_ds
    Storage.where(:id => get_option(:placement_ds_name)).first
  end
end
