module ManageIQ::Providers::Kubernetes
  class ContainerManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
    include ::EmsRefresh::Refreshers::EmsRefresherMixin

    def self.entities
      [{:name => 'pods'}, {:name => 'services'}, {:name => 'replication_controllers'}, {:name => 'nodes'},
       {:name => 'endpoints'}, {:name => 'namespaces'}, {:name => 'resource_quotas'}, {:name => 'limit_ranges'},
       {:name => 'persistent_volumes'}, {:name => 'persistent_volume_claims'},
       # workaround for: https://github.com/openshift/origin/issues/5865
       {:name => 'component_statuses', :default => []}]
    end

    def parse_inventory(ems, _targets = nil)
      all_entities = ems.with_provider_connection { |client| fetch_entities(client, self.class.entities) }
      EmsRefresh.log_inv_debug_trace(all_entities, "inv_hash:")
      ManageIQ::Providers::Kubernetes::ContainerManager::RefreshParser.ems_inv_to_hashes(all_entities)
    end
  end
end
