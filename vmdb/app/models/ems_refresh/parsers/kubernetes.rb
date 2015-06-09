require 'miq-iecunits'

module EmsRefresh::Parsers
  class Kubernetes
    def self.ems_inv_to_hashes(inventory)
      new.ems_inv_to_hashes(inventory)
    end

    def initialize
      @data = {}
      @data_index = {}
    end

    def ems_inv_to_hashes(inventory)
      get_nodes(inventory)
      get_replication_controllers(inventory)
      get_pods(inventory)
      get_endpoints(inventory)
      get_services(inventory)

      EmsRefresh.log_inv_debug_trace(@data, "data:")
      @data
    end

    def get_nodes(inventory)
      process_collection(inventory["node"], :container_nodes) { |n| parse_node(n) }
      @data[:container_nodes].each do |cn|
        @data_index.store_path(:container_nodes, :by_name, cn[:name], cn)
      end
    end

    def get_services(inventory)
      process_collection(inventory["service"], :container_services) { |s| parse_service(s) }
    end

    def get_replication_controllers(inventory)
      process_collection(inventory["replication_controller"],
                         :container_replicators) do |rc|
        parse_replication_controllers(rc)
      end
      @data[:container_replicators].each do |rc|
        @data_index.store_path(:container_replicators,
                               :by_namespace_and_name, rc[:namespace], rc[:name], rc)
      end
    end

    def get_pods(inventory)
      process_collection(inventory["pod"], :container_groups) { |n| parse_pod(n) }
      @data[:container_groups].each do |cg|
        @data_index.store_path(:container_groups, :by_namespace_and_name,
                               cg[:namespace], cg[:name], cg)
      end
    end

    def get_endpoints(inventory)
      process_collection(inventory["endpoint"], :container_endpoints) { |n| parse_endpoint(n) }

      @data[:container_endpoints].each do |ep|
        @data_index.store_path(:container_endpoints, :by_namespace_and_name,
                               ep[:namespace], ep[:name], ep)
      end
    end

    def process_collection(collection, key, &block)
      @data[key] ||= []
      collection.each { |item| process_collection_item(item, key, &block) }
    end

    def process_collection_item(item, key)
      @data[key] ||= []

      new_result = yield(item)

      @data[key] << new_result
      new_result
    end

    def parse_node(node)
      new_result = parse_base_item(node)

      new_result.merge!(
        :type                       => 'ContainerNodeKubernetes',
        :identity_infra             => node.spec.externalID,
        :identity_machine           => node.status.nodeInfo.machineID,
        :identity_system            => node.status.nodeInfo.systemUUID,
        :container_runtime_version  => node.status.nodeInfo.containerRuntimeVersion,
        :kubernetes_proxy_version   => node.status.nodeInfo.kubeProxyVersion,
        :kubernetes_kubelet_version => node.status.nodeInfo.kubeletVersion
      )

      node_memory = node.status.capacity.memory
      node_memory &&= MiqIECUnits.string_to_value(node_memory) / 1.megabyte

      new_result[:computer_system] = {
        :hardware => {
          :logical_cpus => node.status.capacity.cpu,
          :memory_cpu   => node_memory
        },
        :operating_system => {
          :distribution   => node.status.nodeInfo.osImage,
          :kernel_version => node.status.nodeInfo.kernelVersion
        }
      }

      conditions = node.status.conditions
      new_result[:container_node_conditions] = conditions.collect do |condition|
        parse_node_condition(condition)
      end

      new_result
    end

    def parse_service(service)
      new_result = parse_base_item(service)
      if new_result[:ems_ref].nil? # Typically this happens for kubernetes services
        new_result[:ems_ref] = "#{new_result[:namespace]}_#{new_result[:name]}"
      end
      container_groups = []

      endpoint_container_groups = @data_index.fetch_path(
        :container_endpoints, :by_namespace_and_name, new_result[:namespace],
        new_result[:name], :container_groups)
      endpoint_container_groups ||= []

      endpoint_container_groups.each do |group|
        cg = @data_index.fetch_path(
          :container_groups, :by_namespace_and_name, group[:namespace],
          group[:name])
        container_groups << cg unless cg.nil?
      end

      new_result.merge!(
        :portal_ip        => service.spec.portalIP,
        :session_affinity => service.spec.sessionAffinity,

        :labels           => parse_labels(service),
        :selector_parts   => parse_selector_parts(service),
        :container_groups => container_groups
      )

      ports = service.spec.ports
      new_result[:container_service_port_configs] = Array(ports).collect do |port_entry|
        parse_service_port_config(port_entry, new_result[:ems_ref])
      end

      new_result
    end

    def parse_pod(pod)
      # pod in kubernetes is container group in manageiq
      new_result = parse_base_item(pod)

      new_result.merge!(
        :type                 => 'ContainerGroupKubernetes',
        :restart_policy       => pod.spec.restartPolicy,
        :dns_policy           => pod.spec.dnsPolicy,
        :ipaddress            => pod.status.podIP,
        :container_node       => nil,
        :containers           => [],
        :container_replicator => nil
      )

      unless pod.spec.host.nil?
        new_result[:container_node] = @data_index.fetch_path(
          :container_nodes, :by_name, pod.spec.host)
      end

      # TODO, map volumes
      # TODO, podIP
      containers = pod.spec.containers
      new_result[:container_definitions] = containers.collect do |container_def|
        parse_container_definition(container_def, pod.metadata.uid)
      end

      # container instances
      unless pod.status.nil? || pod.status.containerStatuses.nil?
        pod.status.containerStatuses.each do |cn|
          new_result[:containers] << parse_container(cn, pod.metadata.uid)
        end
      end

      # NOTE: what we are trying to access here is the attribute:
      #   pod.metadata.annotations.kubernetes.io/created-by
      # but 'annotations' may be nil. The weird attribute name is
      # generated by the JSON unmarshalling.
      createdby_txt = pod.metadata.annotations.try("kubernetes.io/created-by")
      unless createdby_txt.nil?
        # NOTE: the annotation content is JSON, so it needs to be parsed
        createdby = JSON.parse(createdby_txt)
        if createdby.kind_of?(Hash) && !createdby['reference'].nil?
          new_result[:container_replicator] = @data_index.fetch_path(
            :container_replicators, :by_namespace_and_name,
            createdby['reference']['namespace'], createdby['reference']['name'])
        end
      end

      new_result[:labels] = parse_labels(pod)
      new_result
    end

    def parse_endpoint(entity)
      new_result = parse_base_item(entity)
      new_result[:container_groups] = []

      (entity.subsets || []).each do |subset|
        (subset.addresses || []).each do |address|
          next if address.targetRef.try(:kind) != 'Pod'
          cg = @data_index.fetch_path(
              :container_groups, :by_namespace_and_name,
              # namespace is overriden in more_core_extensions and hence needs
              # a non method access
              address.targetRef["table"][:namespace], address.targetRef.name)
          new_result[:container_groups] << cg unless cg.nil?
        end
      end

      new_result
    end

    def parse_replication_controllers(container_replicator)
      new_result = parse_base_item(container_replicator)

      # TODO: parse template
      new_result.merge!(
        :replicas         => container_replicator.spec.replicas,
        :current_replicas => container_replicator.status.replicas,
        :labels           => parse_labels(container_replicator),
        :selector_parts   => parse_selector_parts(container_replicator)
      )

      new_result
    end

    def parse_labels(entity)
      result = []
      labels = entity.metadata.labels
      return result if labels.nil?
      labels.to_h.each do |key, value|
        custom_attr = {
          :section => 'labels',
          :name    => key,
          :value   => value,
          :source  => "kubernetes"
        }
        result << custom_attr
      end
      result
    end

    def parse_selector_parts(entity)
      result = []
      selector_parts = entity.spec.selector
      return result if selector_parts.nil?
      selector_parts.to_h.each do |key, value|
        custom_attr = {
          :section => 'selectors',
          :name    => key,
          :value   => value,
          :source  => "kubernetes"
        }
        result << custom_attr
      end
      result
    end

    def parse_container_definition(container_def, pod_id)
      new_result = {
        :ems_ref           => "#{pod_id}_#{container_def.name}_#{container_def.image}",
        :name              => container_def.name,
        :image             => container_def.image,
        :image_pull_policy => container_def.imagePullPolicy,
        :memory            => container_def.memory,
         # https://github.com/GoogleCloudPlatform/kubernetes/blob/0b801a91b15591e2e6e156cf714bfb866807bf30/pkg/api/v1beta3/types.go#L815
        :cpu_cores         => container_def.cpu.to_f / 1000
      }
      ports = container_def.ports
      new_result[:container_port_configs] = Array(ports).collect do |port_entry|
        parse_container_port_config(port_entry, pod_id, container_def.name)
      end
      new_result
    end

    def parse_container(container, pod_id)
      {
        :type          => 'ContainerKubernetes',
        :ems_ref       => "#{pod_id}_#{container.name}_#{container.image}",
        :name          => container.name,
        :image         => container.image,
        :restart_count => container.restartCount,
        :backing_ref   => container.containerID,
        :image_ref     => container.imageID
      }
      # TODO, state
    end

    def parse_container_port_config(port_config, pod_id, container_name)
      {
        :ems_ref   => "#{pod_id}_#{container_name}_#{port_config.containerPort}_#{port_config.hostPort}_#{port_config.protocol}",
        :port      => port_config.containerPort,
        :host_port => port_config.hostPort,
        :protocol  => port_config.protocol,
        :name      => port_config.name
      }
    end

    def parse_service_port_config(port_config, service_id)
      {
        :ems_ref     => "#{service_id}_#{port_config.port}_#{port_config.targetPort}",
        :name        => port_config.name,
        :port        => port_config.port,
        :target_port => port_config.targetPort,
        :protocol    => port_config.protocol
      }
    end

    def parse_node_condition(condition)
      {
        :name                 => condition.type,
        :status               => condition.status,
        :last_heartbeat_time  => condition.lastHeartbeatTime,
        :last_transition_time => condition.lastTransitionTime,
        :reason               => condition.reason,
        :message              => condition.message
      }
    end

    private

    def parse_base_item(item)
      {
        :ems_ref            => item.metadata.uid,
        :name               => item.metadata.name,
        # namespace is overriden in more_core_extensions and hence needs
        # a non method access
        :namespace          => item.metadata["table"][:namespace],
        :creation_timestamp => item.metadata.creationTimestamp,
        :resource_version   => item.metadata.resourceVersion
      }
    end
  end
end
