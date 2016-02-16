module ManageIQ::Providers::CloudManager::Provision::Placement
  protected

  def placement
    get_option(:placement_auto) ? automatic_placement : manual_placement
  end

  private

  def automatic_placement
    _log.info("Getting most suitable availability_zone for new instance...")
    availability_zone = get_most_suitable_availability_zone
    availability_zone ||= manual_placement

    options[:placement_availability_zone] = [availability_zone.try(:id), availability_zone.try(:name)]
    _log.info("Getting most suitable availability_zone for new instance...Complete, Availability Zone Id: [#{availability_zone.try(:id)}], Name: [#{availability_zone.try(:name)}]")
    availability_zone
  end

  def manual_placement
    availability_zone = AvailabilityZone.find_by(:id => get_option(:placement_availability_zone))
    _log.info("Using selected availability_zone for new VM, Id: [#{availability_zone.try(:id)}], Name: [#{availability_zone.try(:name)}]")
    availability_zone
  end
end
