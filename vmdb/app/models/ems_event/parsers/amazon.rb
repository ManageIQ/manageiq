module EmsEvent::Parsers::Amazon
  def self.event_to_hash(event, ems_id)
    log_header = "MIQ(#{self.name}.event_to_hash)"
    log_header << " ems_id: [#{ems_id}]" unless ems_id.nil?

    $log.debug("#{log_header} event: [#{event["configurationItem"]["resourceType"]} - " \
               "#{event["configurationItem"]["resourceId"]}]") if $log.debug?

    event_hash = {
      :event_type => event["eventType"],
      :source     => "AMAZON",
      :message    => event["configurationItemDiff"],
      :timestamp  => event["notificationCreationTime"],
      :full_data  => event,
      :ems_id     => ems_id
    }

    event_hash[:vm_ems_ref]                = parse_vm_ref(event)
    event_hash[:availability_zone_ems_ref] = parse_availability_zone_ref(event)
    event_hash
  end

  def self.parse_vm_ref(event)
    resource_type = event["configurationItem"]["resourceType"]
    # other ways to find the VM?
    event.fetch_path("configurationItem", "resourceId") if resource_type == "AWS::EC2::Instance"
  end

  def self.parse_availability_zone_ref(event)
    event.fetch_path("configurationItem", "availabilityZone")
  end
end
