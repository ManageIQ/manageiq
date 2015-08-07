module ManageIQ::Providers
  module Openshift
    class ContainerManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
      include ::EmsRefresh::Refreshers::EmsRefresherMixin

      def parse_inventory(ems, _targets = nil)
        all_entities = ems.with_provider_connection(&:all_entities)
        all_entities.merge!(ems.with_provider_connection(:service => ManageIQ::Providers::Kubernetes::ContainerManager.ems_type, &:all_entities))
        EmsRefresh.log_inv_debug_trace(all_entities, "inv_hash:")
        ManageIQ::Providers::Openshift::ContainerManager::RefreshParser.ems_inv_to_hashes(all_entities)
      end
    end
  end
end
