module MiqProvisionCloud::Placement
  protected

  def placement
    get_option(:placement_auto) ? automatic_placement : manual_placement
  end

  private

  def automatic_placement
    log_header = "MIQ(#{self.class.name}.automatic_placement)"

    $log.info("#{log_header} Getting most suitable availability_zone for new instance...")
    availability_zone = get_most_suitable_availability_zone

    options[:placement_availability_zone] = [availability_zone.try(:id), availability_zone.try(:name)]
    $log.info("#{log_header} Getting most suitable availability_zone for new instance...Complete, Availability Zone Id: [#{availability_zone.try(:id)}], Name: [#{availability_zone.try(:name)}]")
    availability_zone
  end

  def manual_placement
    availability_zone = AvailabilityZone.where(:id => get_option(:placement_availability_zone)).first
    $log.info("MIQ(#{self.class.name}.manual_placement) Using selected availability_zone for new VM, Id: [#{availability_zone.try(:id)}], Name: [#{availability_zone.try(:name)}]")
    availability_zone
  end
end
