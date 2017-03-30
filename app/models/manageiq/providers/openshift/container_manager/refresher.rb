module ManageIQ::Providers
  module Openshift
    class ContainerManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
      include ::EmsRefresh::Refreshers::EmsRefresherMixin
      include ManageIQ::Providers::Kubernetes::ContainerManager::RefresherMixin

      KUBERNETES_EMS_TYPE = ManageIQ::Providers::Kubernetes::ContainerManager.ems_type
      OPENSHIFT_EMS_TYPE = ManageIQ::Providers::Openshift::ContainerManager.ems_type

      OPENSHIFT_ENTITIES = [
        {:name => 'routes'}, {:name => 'projects'},
        {:name => 'build_configs'}, {:name => 'builds'}, {:name => 'templates'},
        {:name => 'images'}
      ]

      def fetch_hawk_inv(ems)
        hawk = ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCapture::HawkularClient.new(ems, '_ops')
        keys = hawk.strings.query(:miq_metric => true)
        keys.each_with_object({}) do |k, attributes|
          values = hawk.strings.get_data(k.json["id"], :limit => 1, :order => "DESC")
          attributes[k.json["id"]] = values.first["value"] unless values.empty?
        end
      rescue => err
        _log.error err.message
        return nil
      end

      def parse_legacy_inventory(ems)
        kube_entities = ems.with_provider_connection(:service => KUBERNETES_EMS_TYPE) do |kubeclient|
          fetch_entities(kubeclient, KUBERNETES_ENTITIES)
        end
        openshift_entities = ems.with_provider_connection do |openshift_client|
          fetch_entities(openshift_client, OPENSHIFT_ENTITIES)
        end
        entities = openshift_entities.merge(kube_entities)
        entities["additional_attributes"] = fetch_hawk_inv(ems) || {}
        EmsRefresh.log_inv_debug_trace(entities, "inv_hash:")
        ManageIQ::Providers::Openshift::ContainerManager::RefreshParser.ems_inv_to_hashes(entities)
      end

      def inlined_refresh1(ems)
        # fetch
        kclient = ems.connect(:service => KUBERNETES_EMS_TYPE)
        oclient = ems.connect(:service => OPENSHIFT_EMS_TYPE)
        inventory = {}
        inventory["pod"] = kclient.get_pods
        inventory["service"] = kclient.get_services
        inventory["replication_controller"] = kclient.get_replication_controllers
        inventory["node"] = kclient.get_nodes
        inventory["endpoint"] = kclient.get_endpoints
        inventory["namespace"] = kclient.get_namespaces
        inventory["resource_quota"] = kclient.get_resource_quotas
        inventory["limit_range"] = kclient.get_limit_ranges
        inventory["persistent_volume"] = kclient.get_persistent_volumes
        inventory["persistent_volume_claim"] = kclient.get_persistent_volume_claims
        inventory["component_status"] = kclient.get_component_statuses
        inventory["route"] = oclient.get_routes
        inventory["project"] = oclient.get_projects
        inventory["build_config"] = oclient.get_build_configs
        inventory["build"] = oclient.get_builds
        inventory["template"] = oclient.get_templates
        inventory["image"] = oclient.get_images
        inventory["additional_attributes"] = fetch_hawk_inv(ems) || {}
        EmsRefresh.log_inv_debug_trace(inventory, "inv_hash:")

        # parse
        parser = ManageIQ::Providers::Openshift::ContainerManager::RefreshParser.new
        parser.get_additional_attributes(inventory)
        parser.get_nodes(inventory)
        parser.get_namespaces(inventory)
        parser.get_resource_quotas(inventory)
        parser.get_limit_ranges(inventory)
        parser.get_replication_controllers(inventory)
        parser.get_persistent_volume_claims(inventory)
        parser.get_persistent_volumes(inventory)
        parser.get_pods(inventory)
        parser.get_endpoints(inventory)
        parser.get_services(inventory)
        parser.get_component_statuses(inventory)
        parser.get_projects(inventory)
        parser.get_routes(inventory)
        parser.get_builds(inventory)
        parser.get_build_pods(inventory)
        parser.get_templates(inventory)
        parser.get_openshift_images(inventory)
        data = parser.data
        EmsRefresh.log_inv_debug_trace(data, "data:")

        # save
        target = ems
        #EmsRefresh.save_ems_container_inventory(ems, data, target)
        EmsRefresh.save_container_projects_inventory(ems, data[:container_projects], target)
        EmsRefresh.save_container_quotas_inventory(ems, data[:container_quotas], target)
        EmsRefresh.save_container_limits_inventory(ems, data[:container_limits], target)
        EmsRefresh.save_container_nodes_inventory(ems, data[:container_nodes], target)
        EmsRefresh.save_container_builds_inventory(ems, data[:container_builds], target)
        EmsRefresh.save_container_build_pods_inventory(ems, data[:container_build_pods], target)
        EmsRefresh.save_persistent_volume_claims_inventory(ems, data[:persistent_volume_claims], target)
        EmsRefresh.save_persistent_volumes_inventory(ems, data[:persistent_volume_claims], target)
        EmsRefresh.save_container_image_registries_inventory(ems, data[:container_image_registries], target)
        EmsRefresh.save_container_images_inventory(ems, data[:container_images], target)
        EmsRefresh.save_container_replicators_inventory(ems, data[:container_replicators], target)
        EmsRefresh.save_container_groups_inventory(ems, data[:container_groups], target)
        EmsRefresh.save_container_services_inventory(ems, data[:container_services], target)
        EmsRefresh.save_container_routes_inventory(ems, data[:container_routes], target)
        EmsRefresh.save_container_component_statuses_inventory(ems, data[:container_component_statuses], target)
        EmsRefresh.save_container_templates_inventory(ems, data[:container_templates], target)
      end

      def inlined_refresh2(ems)
        inlined_refresh_nodes(ems)
        inlined_refresh_projects(ems)
        inlined_refresh_rest(ems)
      end

      def inlined_refresh_nodes(ems)
        kclient = ems.connect(:service => KUBERNETES_EMS_TYPE)
        inventory = {}
        inventory["additional_attributes"] = fetch_hawk_inv(ems) || {}
        inventory["node"] = kclient.get_nodes
        parser = ManageIQ::Providers::Openshift::ContainerManager::RefreshParser.new
        parser.get_additional_attributes(inventory)
        parser.get_nodes(inventory)
        EmsRefresh.save_container_nodes_inventory(ems, parser.data[:container_nodes], ems)

        $inventory1, $parser1 = inventory, parser  # for debugging
      end

      def inlined_refresh_projects(ems)
        kclient = ems.connect(:service => KUBERNETES_EMS_TYPE)
        oclient = ems.connect(:service => OPENSHIFT_EMS_TYPE)
        inventory = {}
        inventory["namespace"] = kclient.get_namespaces
        inventory["project"] = oclient.get_projects
        parser = ManageIQ::Providers::Openshift::ContainerManager::RefreshParser.new
        parser.get_namespaces(inventory)
        parser.get_projects(inventory)
        EmsRefresh.save_container_projects_inventory(ems, parser.data[:container_projects], ems)

        $inventory2, $parser2 = inventory, parser  # for debugging
      end

      def inlined_refresh_rest(ems)
        # fetch
        kclient = ems.connect(:service => KUBERNETES_EMS_TYPE)
        oclient = ems.connect(:service => OPENSHIFT_EMS_TYPE)
        inventory = {}
        inventory["pod"] = kclient.get_pods
        inventory["service"] = kclient.get_services
        inventory["replication_controller"] = kclient.get_replication_controllers
        inventory["endpoint"] = kclient.get_endpoints
        inventory["resource_quota"] = kclient.get_resource_quotas
        inventory["limit_range"] = kclient.get_limit_ranges
        inventory["persistent_volume"] = kclient.get_persistent_volumes
        inventory["persistent_volume_claim"] = kclient.get_persistent_volume_claims
        inventory["component_status"] = kclient.get_component_statuses
        inventory["route"] = oclient.get_routes
        inventory["build_config"] = oclient.get_build_configs
        inventory["build"] = oclient.get_builds
        inventory["template"] = oclient.get_templates
        inventory["image"] = oclient.get_images
        EmsRefresh.log_inv_debug_trace(inventory, "inv_hash:")

        # parse
        parser = ManageIQ::Providers::Openshift::ContainerManager::RefreshParser.new
        # load back ids
        ems.container_projects.each { |r| parser.data_index.store_path(:container_projects, :by_name, r.name, {:id => r.id}) }
        ems.container_nodes.each { |r| parser.data_index.store_path(:container_nodes, :by_name, r.name, {:id => r.id}) }

        parser.get_resource_quotas(inventory)
        parser.get_limit_ranges(inventory)
        parser.get_replication_controllers(inventory)
        parser.get_persistent_volume_claims(inventory)
        parser.get_persistent_volumes(inventory)
        parser.get_pods(inventory)
        parser.get_endpoints(inventory)
        parser.get_services(inventory)
        parser.get_component_statuses(inventory)
        parser.get_routes(inventory)
        parser.get_builds(inventory)
        parser.get_build_pods(inventory)
        parser.get_templates(inventory)
        parser.get_openshift_images(inventory)
        EmsRefresh.log_inv_debug_trace(parser.data, "data:")

        # save
        target = ems
        EmsRefresh.save_container_quotas_inventory(ems, parser.data[:container_quotas], target)
        EmsRefresh.save_container_limits_inventory(ems, parser.data[:container_limits], target)
        EmsRefresh.save_container_builds_inventory(ems, parser.data[:container_builds], target)
        EmsRefresh.save_container_build_pods_inventory(ems, parser.data[:container_build_pods], target)
        EmsRefresh.save_persistent_volume_claims_inventory(ems, parser.data[:persistent_volume_claims], target)
        EmsRefresh.save_persistent_volumes_inventory(ems, parser.data[:persistent_volume_claims], target)
        EmsRefresh.save_container_image_registries_inventory(ems, parser.data[:container_image_registries], target)
        EmsRefresh.save_container_images_inventory(ems, parser.data[:container_images], target)
        EmsRefresh.save_container_replicators_inventory(ems, parser.data[:container_replicators], target)
        EmsRefresh.save_container_groups_inventory(ems, parser.data[:container_groups], target)
        EmsRefresh.save_container_services_inventory(ems, parser.data[:container_services], target)
        EmsRefresh.save_container_routes_inventory(ems, parser.data[:container_routes], target)
        EmsRefresh.save_container_component_statuses_inventory(ems, parser.data[:container_component_statuses], target)
        EmsRefresh.save_container_templates_inventory(ems, parser.data[:container_templates], target)
      end
    end
  end
end
