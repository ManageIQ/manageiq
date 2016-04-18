class ManageIQ::Providers::Amazon::CloudManager::EventCatcher::Parser < ManageIQ::Providers::BaseManager::EventCatcher::Parser

  def event_to_hash(event)
    _log.debug("event: [#{event["configurationItem"]["resourceType"]} - " \
               "#{event["configurationItem"]["resourceId"]}]")

    event_hash = {
      :event_type => event["eventType"],
      :source     => "AMAZON",
      :message    => event["configurationItemDiff"],
      :timestamp  => event["notificationCreationTime"],
      :full_data  => event,
    }

    event_hash[:vm_ems_ref]                = parse_vm_ref(event)
    event_hash[:availability_zone_ems_ref] = parse_availability_zone_ref(event)
    event_hash
  end

  def filtered?(event)
    filtered_events.include?(event["messageType"])
  end

  private
  def parse_vm_ref(event)
    resource_type = event["configurationItem"]["resourceType"]
    # other ways to find the VM?
    event.fetch_path("configurationItem", "resourceId") if resource_type == "Aws::EC2::Instance"
  end

  def parse_availability_zone_ref(event)
    event.fetch_path("configurationItem", "availabilityZone")
  end
end
