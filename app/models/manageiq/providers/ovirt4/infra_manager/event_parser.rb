module ManageIQ::Providers::Ovirt4::InfraManager::EventParser
  def self.event_to_hash(event, ems_id = nil)
    log_header = "ems_id: [#{ems_id}] " unless ems_id.nil?

    _log.debug { "#{log_header}event: [#{event.inspect}]" }

    # Follow the link to the user, as we need the name:
    ems = ManageIQ::Providers::Redhat::InfraManager.find_by_id(ems_id)
    connection = ems.connect(:version => 4)
    user = connection.follow_link(event.user)

    # Build the event hash:
    {
      :event_type          => event.name,
      :source              => 'RHEVM',
      :message             => event.description,
      :timestamp           => event.time,
      :username            => user.name,
      :full_data           => event,
      :ems_id              => ems_id,
      :vm_ems_ref          => ems_ref_from_object_in_event(event.vm) || ems_ref_from_object_in_event(event.template),
      :host_ems_ref        => ems_ref_from_object_in_event(event.host),
      :ems_cluster_ems_ref => ems_ref_from_object_in_event(event.cluster),
    }
  end

  def self.ems_ref_from_object_in_event(data)
    ManageIQ::Providers::Redhat::InfraManager.make_ems_ref(data.href)
  end

end
