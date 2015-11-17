module ManageIQ::Providers
  module Openshift
    class ContainerManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
      include ::EmsRefresh::Refreshers::EmsRefresherMixin

      KUBERNETES_EMS_TYPE = ManageIQ::Providers::Kubernetes::ContainerManager.ems_type

      def self.entities
        [{:name => 'routes'}, {:name => 'projects'}]
      end

      def parse_inventory(ems, _targets = nil)
        openshift_entities = ems.with_provider_connection { |client| fetch_entities(client, self.class.entities) }
        kubernetes_entities = ems.with_provider_connection(:service => KUBERNETES_EMS_TYPE) do |client|
          fetch_entities(client, ManageIQ::Providers::Kubernetes::ContainerManager::Refresher.entities)
        end
        all_entities = openshift_entities.merge(kubernetes_entities)
        EmsRefresh.log_inv_debug_trace(all_entities, "inv_hash:")
        ManageIQ::Providers::Openshift::ContainerManager::RefreshParser.ems_inv_to_hashes(all_entities)
      end
    end
  end
end
