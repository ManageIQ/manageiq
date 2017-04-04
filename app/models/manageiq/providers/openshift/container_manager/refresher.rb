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
        ems.save!
      end

      def inlined_refresh2(ems)
        inlined_refresh_nodes(ems)
        inlined_refresh_component_statuses(ems)
        inlined_refresh_images(ems)
        inlined_refresh_projects(ems)
        inv = inlined_inventory_rest(ems)
        inlined_parse_save_rest(ems, ems, inv)
      end

      def inlined_refresh3(ems, fake_split: false)
        inlined_refresh_nodes(ems)
        inlined_refresh_component_statuses(ems)
        inlined_refresh_images(ems)
        inlined_refresh_projects(ems)

        @split_counts = {}
        # Without this .reset, `ems.container_projects` sees each
        # project twice in one of the tests.
        # TODO: understand why, and if more .resets are needed?
        ems.container_projects.reset
        ems.container_projects.each do |project|
          if fake_split
            inventory = inlined_inventory_rest_fake_split(ems, namespace: project.name)
          else
            inventory = inlined_inventory_rest(ems, namespace: project.name)
          end
          inlined_parse_save_rest(ems, project, inventory)
        end
        byebug if @split_counts != @orig_counts
      end

      def inlined_refresh3_fake(ems)
        inlined_refresh_nodes(ems)
        inlined_refresh_component_statuses(ems)
        inlined_refresh_images(ems)
        inlined_refresh_projects(ems)
        ems.container_projects.each do |project|
          byebug if project.name == 'default'
          inlined_parse_save_rest(ems, project, inventory)
        end
        byebug
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
        ems.save!
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
        ems.save!
      end

      def inlined_refresh_component_statuses(ems)
        kclient = ems.connect(:service => KUBERNETES_EMS_TYPE)
        inventory = {}
        inventory["component_status"] = kclient.get_component_statuses
        parser = ManageIQ::Providers::Openshift::ContainerManager::RefreshParser.new
        parser.get_component_statuses(inventory)
        EmsRefresh.save_container_component_statuses_inventory(ems, parser.data[:container_component_statuses], ems)
        ems.save!
      end

      def inlined_refresh_images(ems)
        oclient = ems.connect(:service => OPENSHIFT_EMS_TYPE)
        inventory = {}
        inventory["image"] = oclient.get_images
        parser = ManageIQ::Providers::Openshift::ContainerManager::RefreshParser.new
        parser.get_openshift_images(inventory)
        EmsRefresh.save_container_image_registries_inventory(ems, parser.data[:container_image_registries], ems)
        EmsRefresh.save_container_images_inventory(ems, parser.data[:container_images], ems)
        ems.save!
      end

      def inlined_inventory_rest(ems, *kubeclient_args)
        # fetch
        kclient = ems.connect(:service => KUBERNETES_EMS_TYPE)
        oclient = ems.connect(:service => OPENSHIFT_EMS_TYPE)
        inventory = {}
        inventory["pod"] = kclient.get_pods(*kubeclient_args)
        inventory["service"] = kclient.get_services(*kubeclient_args)
        inventory["replication_controller"] = kclient.get_replication_controllers(*kubeclient_args)
        inventory["endpoint"] = kclient.get_endpoints(*kubeclient_args)
        inventory["resource_quota"] = kclient.get_resource_quotas(*kubeclient_args)
        inventory["limit_range"] = kclient.get_limit_ranges(*kubeclient_args)
        inventory["persistent_volume"] = kclient.get_persistent_volumes(*kubeclient_args)
        inventory["persistent_volume_claim"] = kclient.get_persistent_volume_claims(*kubeclient_args)
        inventory["route"] = oclient.get_routes(*kubeclient_args)
        inventory["build_config"] = oclient.get_build_configs(*kubeclient_args)
        inventory["build"] = oclient.get_builds(*kubeclient_args)
        inventory["template"] = oclient.get_templates(*kubeclient_args)
        EmsRefresh.log_inv_debug_trace(inventory, "inv_hash:")
        inventory
      end

      # Fake per-project fetching without re-recording cassettes
      # Needs :allow_playback_repeats => true
      def inlined_inventory_rest_fake_split(ems, namespace:)
        full_inv = inlined_inventory_rest(ems)
        @orig_counts = full_inv.transform_values(&:count)
        full_inv.each do |k, structs|
          structs.select! { |s| s.metadata.namespace == namespace }
          @split_counts[k] ||= 0
          @split_counts[k] += structs.count
        end
        full_inv
      end

      def inlined_parse_save_rest(ems, target, inventory)
        # parse
        parser = ManageIQ::Providers::Openshift::ContainerManager::RefreshParser.new
        # load back ids. TODO: lazy for only the mentioned ones?
        ems.container_projects.each { |r| parser.data_index.store_path(:container_projects, :by_name, r.name, {:id => r.id}) }
        ems.container_nodes.each { |r| parser.data_index.store_path(:container_nodes, :by_name, r.name, {:id => r.id}) }
        ems.container_image_registries.each { |r| parser.data_index.store_path(:container_image_registry, :by_host_and_port, "#{r.host}:#{r.port}", {:id => r.id}) }
        ems.container_images.each { |r| parser.data_index.store_path(:container_image, :by_digest, r.digest || r.image_ref, {:id => r.id}) }

        parser.get_resource_quotas(inventory)
        parser.get_limit_ranges(inventory)
        parser.get_replication_controllers(inventory)
        parser.get_persistent_volume_claims(inventory)
        parser.get_persistent_volumes(inventory)
        parser.get_pods(inventory)
        parser.get_endpoints(inventory)
        parser.get_services(inventory)
        parser.get_routes(inventory)
        parser.get_builds(inventory)
        parser.get_build_pods(inventory)
        parser.get_templates(inventory)
        EmsRefresh.log_inv_debug_trace(parser.data, "data:")

        # save
        EmsRefresh.save_container_quotas_inventory(ems, parser.data[:container_quotas], target)
        EmsRefresh.save_container_limits_inventory(ems, parser.data[:container_limits], target)
        EmsRefresh.save_container_builds_inventory(ems, parser.data[:container_builds], target)
        EmsRefresh.save_container_build_pods_inventory(ems, parser.data[:container_build_pods], target)
        EmsRefresh.save_persistent_volume_claims_inventory(ems, parser.data[:persistent_volume_claims], target)
        EmsRefresh.save_persistent_volumes_inventory(ems, parser.data[:persistent_volume_claims], target)
        # TODO is re-saving images here needed?
        EmsRefresh.save_container_image_registries_inventory(ems, parser.data[:container_image_registries], target)
        EmsRefresh.save_container_images_inventory(ems, parser.data[:container_images], target)
        EmsRefresh.save_container_replicators_inventory(ems, parser.data[:container_replicators], target)
        EmsRefresh.save_container_groups_inventory(ems, parser.data[:container_groups], target)
        EmsRefresh.save_container_services_inventory(ems, parser.data[:container_services], target)
        EmsRefresh.save_container_routes_inventory(ems, parser.data[:container_routes], target)
        EmsRefresh.save_container_templates_inventory(ems, parser.data[:container_templates], target)
      end
    end
  end
end
