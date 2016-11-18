module ManageIQ::Providers::Azure::EventCatcherMixin
  def parse_event_type(event)
    event_name   = event["eventName"]["value"]
    event_action = event.fetch_path("authorization", "action")
    event_type   = parse_event_action(event_action) if event_action

    "#{event_type}#{event_name}"
  end

  def parse_event_action(event_action)
    # E.g. Microsoft.Compute/virtualMachines/deallocate/action

    _provider, object_class, event_type, _action = event_action.split("/")
    "#{object_class}_#{event_type}_"
  end

  def parse_vm_ref(event)
    # E.g. /subscriptions/123456789-a1234-12b4-1234-5cd67890312/resourceGroups/
    # rg_name/providers/Microsoft.Compute/virtualMachines/vm_name

    return nil if event["resourceId"].length < 9

    _empty_space,
    _subscriptions,
    subscription_id,
    _resource_groups,
    resource_group,
    _providers,
    provider,
    object_class,
    object_name = event["resourceId"].split("/")

    [subscription_id, resource_group.downcase, "#{provider.downcase}\/#{object_class.downcase}", object_name].join("\\")
  end
end
