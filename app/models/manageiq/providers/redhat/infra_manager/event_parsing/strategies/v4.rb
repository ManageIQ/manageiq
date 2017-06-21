module ManageIQ::Providers::Redhat::InfraManager::EventParsing::Strategies
  class V4 < ManageIQ::Providers::Redhat::InfraManager::EventParsing::Parser
    def self.event_to_hash(event, ems_id = nil)
      log_header = "ems_id: [#{ems_id}] " unless ems_id.nil?

      _log.debug { "#{log_header}event: [#{event.inspect}]" }

      # Connect back to RHEV to get the actual user_name
      ems       = ManageIQ::Providers::Redhat::InfraManager.find_by(:id => ems_id)
      user_href = ems_ref_from_object_in_event(event.user)
      username  = nil
      if ems && user_href
        username = ems.ovirt_services.username_by_href(user_href)
      end

      # Build the event hash
      {
        :event_type          => event.name,
        :source              => 'RHEVM',
        :message             => event.description,
        :timestamp           => event.time,
        :username            => username,
        :full_data           => event,
        :ems_id              => ems_id,
        :vm_ems_ref          => ems_ref_from_object_in_event(event.vm) || ems_ref_from_object_in_event(event.template),
        :host_ems_ref        => ems_ref_from_object_in_event(event.host),
        :ems_cluster_ems_ref => ems_ref_from_object_in_event(event.cluster),
      }
    end

    def self.ems_ref_from_object_in_event(data)
      return nil unless data && data.href
      ManageIQ::Providers::Redhat::InfraManager.make_ems_ref(data.href)
    end

    def self.parse_new_target(full_data, message, ems, event_type)
      cluster = full_data.cluster
      cluster_ref = ManageIQ::Providers::Redhat::InfraManager.make_ems_ref(cluster.href)
      cluster_name = ems.ovirt_services.cluster_name_href(cluster_ref)

      {
        :ems_id         => ems.id,
        :vm             => parse_new_vm(full_data.vm, message, event_type, ems),
        :cluster        => parse_new_cluster(cluster_ref, cluster.id, cluster_name),
        :resource_pools => parse_new_resource_pool(cluster.id, cluster_name),
        :folders        => parse_new_dc(full_data.data_center)
      }
    end

    def self.parse_new_vm(vm, message, event_type, ems)
      ems_ref = ManageIQ::Providers::Redhat::InfraManager.make_ems_ref(vm.href)
      parser = ManageIQ::Providers::Redhat::InfraManager::Refresh::Parse::ParserBuilder.new(ems).build
      parser.create_vm_hash(ems_ref.include?('/templates/'), ems_ref, vm.id, parse_target_name(message, event_type))
    end

    def self.parse_new_dc(dc)
      {:ems_ref => ManageIQ::Providers::Redhat::InfraManager.make_ems_ref(dc.href)}
    end
  end
end
