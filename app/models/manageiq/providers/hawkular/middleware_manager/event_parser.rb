module ManageIQ::Providers::Hawkular::MiddlewareManager::EventParser
  def self.event_to_hash(event, ems_id = nil)
    $mw_log.debug "ems_id: [#{ems_id}] event: [#{event.inspect}]"
    {
      :event_type => event[:event_type],
      :source     => 'HAWKULAR',
      :timestamp  => event[:timestamp],
      :message    => event[:message],
      :ems_ref    => event[:resource], # not sure about this, possible link from event to resource?
      :full_data  => event,
      :ems_id     => ems_id
    }
  end
end
