module ManageIQ::Providers::Azure::EventCatcherMixin
  def parse_event_type(event)
    event_name = event["eventName"]["value"]
    event_type = ""

    unless event["authorization"].nil? || event["authorization"]["action"].nil?
      event_type = parse_event_action(event)
    end
    "#{event_type}#{event_name}"
  end

  def parse_event_action(event)
    action = event["authorization"]["action"].split("/")
    "#{action[1]}_#{action[2]}_"
  end

  def parse_vm_ref(event)
    resource_id = event["resourceId"].downcase.split("/")
    return nil if resource_id.length < 9
    join(
      resource_id[2],
      resource_id[4],
      resource_id[6] + "\/" + resource_id[7],
      resource_id[8]
    )
  end

  def join(*keys)
    keys.join('\\')
  end
end
