module ManageIQ::Providers::Kubernetes::ContainerManager::EventParserMixin
  extend ActiveSupport::Concern

  included do
    def self.event_to_hash(event, ems_id = nil)
      log_header = "ems_id: [#{ems_id}]"

      _log.debug("#{log_header} event: [#{event.inspect}]")

      event_type = "#{event[:kind].upcase}_#{event[:reason].upcase}"

      {
        :event_type           => event_type,
        :source               => 'KUBERNETES',
        :timestamp            => event[:timestamp],
        :message              => event[:message],
        :container_node_name  => event[:container_node_name],
        :container_group_name => event[:container_group_name],
        :container_namespace  => event[:container_namespace],
        :container_name       => event[:container_name],
        :full_data            => event,
        :ems_id               => ems_id
      }
    end
  end
end
