module ManageIQ::Providers::Kubernetes
  class ContainerManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
    include ::EmsRefresh::Refreshers::EmsRefresherMixin

    def self.entities
      %w(pods services replication_controllers nodes endpoints namespaces resource_quotas limit_ranges
         persistent_volumes persistent_volume_claims component_statuses)
    end

    def parse_inventory(ems, _targets = nil)
      all_entities = ems.with_provider_connection { |client| fetch_entities(client, self.class.entities) }
      EmsRefresh.log_inv_debug_trace(all_entities, "inv_hash:")
      ManageIQ::Providers::Kubernetes::ContainerManager::RefreshParser.ems_inv_to_hashes(all_entities)
    end
  end
end
