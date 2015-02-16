module EmsEvent::Parsers::Kubernetes
  def self.event_to_hash(event, ems_id = nil)
    log_header = "MIQ(#{name}.event_to_hash) ems_id: [#{ems_id}]"

    $log.debug("#{log_header} event: [#{event.inspect}]")

    event_type = "#{event[:kind].upcase}_#{event[:reason].upcase}"

    {
      :event_type           => event_type,
      :source               => 'KUBERNETES',
      :timestamp            => event[:timestamp],
      :message              => event[:message],
      :container_node_name  => event[:container_node_name],
      :container_group_name => event[:container_group_name],
      :container_namespace  => event[:container_namespace],
      :full_data            => event,
      :ems_id               => ems_id
    }
  end
end
