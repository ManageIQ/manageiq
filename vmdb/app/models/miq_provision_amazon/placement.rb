module MiqProvisionAmazon::Placement
  protected

  def placement
    availability_zone = if get_option(:placement_auto) == true
                          automatic_placement
                        else
                          raise MiqException::MiqProvisionError, "Destination availability_zone not provided" if get_option(:placement_availability_zone).blank?
                          manual_placement
                        end
    raise MiqException::MiqProvisionError, "Unable to find a suitable availability_zone" if availability_zone.nil?
    availability_zone
  end
end
