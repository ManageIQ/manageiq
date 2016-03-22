module ManageIQ::Providers::Kubernetes
  class ContainerManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
    include ::EmsRefresh::Refreshers::EmsRefresherMixin
    include ManageIQ::Providers::Kubernetes::ContainerManager::RefresherMixin

    def parse_legacy_inventory(ems)
      entities = ems.with_provider_connection { |client| fetch_entities(client, KUBERNETES_ENTITIES) }
      EmsRefresh.log_inv_debug_trace(entities, "inv_hash:")
      ManageIQ::Providers::Kubernetes::ContainerManager::RefreshParser.ems_inv_to_hashes(entities)
    end
  end
end
