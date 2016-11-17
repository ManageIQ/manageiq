module ManageIQ::Providers
  module Openshift
    class ContainerManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
      include ::EmsRefresh::Refreshers::EmsRefresherMixin
      include ManageIQ::Providers::Kubernetes::ContainerManager::RefresherMixin

      KUBERNETES_EMS_TYPE = ManageIQ::Providers::Kubernetes::ContainerManager.ems_type

      OPENSHIFT_ENTITIES = [
        {:name => 'routes'}, {:name => 'projects'},
        {:name => 'build_configs'}, {:name => 'builds'}, {:name => 'templates'},
        {:name => 'images'}
      ]

      def parse_legacy_inventory(ems)
        kube_entities = ems.with_provider_connection(:service => KUBERNETES_EMS_TYPE) do |kubeclient|
          fetch_entities(kubeclient, KUBERNETES_ENTITIES)
        end
        openshift_entities = ems.with_provider_connection do |openshift_client|
          fetch_entities(openshift_client, OPENSHIFT_ENTITIES)
        end
        entities = openshift_entities.merge(kube_entities)
        EmsRefresh.log_inv_debug_trace(entities, "inv_hash:")
        ManageIQ::Providers::Openshift::ContainerManager::RefreshParser.ems_inv_to_hashes(entities)
      end
    end
  end
end
