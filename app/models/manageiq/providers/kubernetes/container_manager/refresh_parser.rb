require 'miq-iecunits'
require 'shellwords'

module ManageIQ::Providers::Kubernetes
  class ContainerManager::RefreshParser
    def self.ems_inv_to_hashes(inventory)
      new.ems_inv_to_hashes(inventory)
    end

    def initialize
      @data = {}
      @data_index = {}
    end

    def ems_inv_to_hashes(inventory)
      get_nodes(inventory)
      get_namespaces(inventory)
      get_replication_controllers(inventory)
      get_pods(inventory)
      get_endpoints(inventory)
      get_services(inventory)
      get_registries
      get_images

      EmsRefresh.log_inv_debug_trace(@data, "data:")
      @data
    end

    def get_images
      images = @data_index.fetch_path(:container_image, :by_ref_and_registry_host_port).try(:values) || []
      process_collection(images, :container_images) { |n| n }
    end

    def get_registries
      registries = @data_index.fetch_path(:container_image_registry, :by_host_and_port).try(:values) || []
      process_collection(registries, :container_image_registries) { |n| n }
    end

    def get_nodes(inventory)
      process_collection(inventory["node"], :container_nodes) { |n| parse_node(n) }
      @data[:container_nodes].each do |cn|
        @data_index.store_path(:container_nodes, :by_name, cn[:name], cn)
      end
    end

    def get_services(inventory)
      process_collection(inventory["service"], :container_services) { |s| parse_service(s) }
      @data[:container_services].each do |se|
        @data_index.store_path(:container_services, :by_namespace_and_name, se[:namespace], se[:name], se)
      end
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

    def get_namespaces(inventory)
      process_collection(inventory["namespace"], :container_projects) { |n| parse_namespaces(n) }

      @data[:container_projects].each do |ns|
        @data_index.store_path(:container_projects, :by_name, ns[:name], ns)
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
        :type                       => 'ManageIQ::Providers::Kubernetes::ContainerManager::ContainerNode',
        :identity_infra             => node.spec.externalID,
        :identity_machine           => node.status.nodeInfo.machineID,
        :identity_system            => node.status.nodeInfo.systemUUID,
        :container_runtime_version  => node.status.nodeInfo.containerRuntimeVersion,
        :kubernetes_proxy_version   => node.status.nodeInfo.kubeProxyVersion,
        :kubernetes_kubelet_version => node.status.nodeInfo.kubeletVersion,
        :labels                     => parse_labels(node),
        :lives_on_id                => nil,
        :lives_on_type              => nil
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

      max_container_groups = node.status.capacity.pods
      new_result[:max_container_groups] = max_container_groups && MiqIECUnits.string_to_value(max_container_groups)

      new_result[:container_conditions] = parse_conditions(node)

      # Establish a relationship between this node and the vm it is on (if it is in the system)
      # supported relationships: oVirt, Openstack and VMware.
      types = [ManageIQ::Providers::Redhat::InfraManager::Vm.name,
               ManageIQ::Providers::Openstack::CloudManager::Vm.name,
               ManageIQ::Providers::Vmware::InfraManager::Vm.name]

      # Searching for the underlying instance for Openstack or oVirt.
      vms = Vm.where(:uid_ems => new_result[:identity_system].downcase, :type => types)
      if vms.to_a.size == 1
        new_result[:lives_on_id] = vms.first.id
        new_result[:lives_on_type] = vms.first.type
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
        # TODO: We might want to change portal_ip to clusterIP
        :portal_ip        => service.spec.clusterIP,
        :session_affinity => service.spec.sessionAffinity,

        :labels           => parse_labels(service),
        :selector_parts   => parse_selector_parts(service),
        :container_groups => container_groups
      )

      ports = service.spec.ports
      new_result[:container_service_port_configs] = Array(ports).collect do |port_entry|
        parse_service_port_config(port_entry, new_result[:ems_ref])
      end

      new_result[:project] = @data_index.fetch_path(:container_projects, :by_name,
                                                    service.metadata["table"][:namespace])
      new_result
    end

    def parse_pod(pod)
      # pod in kubernetes is container group in manageiq
      new_result = parse_base_item(pod)

      new_result.merge!(
        :type                  => 'ManageIQ::Providers::Kubernetes::ContainerManager::ContainerGroup',
        :restart_policy        => pod.spec.restartPolicy,
        :dns_policy            => pod.spec.dnsPolicy,
        :ipaddress             => pod.status.podIP,
        :phase                 => pod.status.phase,
        :message               => pod.status.message,
        :reason                => pod.status.reason,
        :container_node        => nil,
        :container_definitions => [],
        :container_replicator  => nil
      )

      unless pod.spec.nodeName.nil?
        new_result[:container_node] = @data_index.fetch_path(
          :container_nodes, :by_name, pod.spec.nodeName)
      end

      new_result[:project] = @data_index.fetch_path(:container_projects, :by_name, pod.metadata["table"][:namespace])

      # TODO, map volumes
      # TODO, podIP
      containers_index = {}
      containers = pod.spec.containers
      unless pod.status.nil? || pod.status.containerStatuses.nil?
        pod.status.containerStatuses.each do |cn|
          containers_index[cn.name] = parse_container(cn, pod.metadata.uid)
        end
      end

      new_result[:container_definitions] = containers.collect do |container_def|
        parse_container_definition(container_def, pod.metadata.uid).merge(
          :container => containers_index[container_def.name]
        )
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

      new_result[:container_conditions] = parse_conditions(pod)

      new_result[:labels] = parse_labels(pod)
      new_result[:node_selector_parts] = parse_node_selector_parts(pod)
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

    def parse_namespaces(container_projects)
      parse_base_item(container_projects).except(:namespace)
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

      new_result[:project] = @data_index.fetch_path(:container_projects, :by_name,
                                                    container_replicator.metadata["table"][:namespace])
      new_result
    end

    def parse_labels(entity)
      parse_identifying_attributes(entity.metadata.labels, 'labels')
    end

    def parse_selector_parts(entity)
      parse_identifying_attributes(entity.spec.selector, 'selectors')
    end

    def parse_node_selector_parts(entity)
      parse_identifying_attributes(entity.spec.nodeSelector, 'node_selectors')
    end

    def parse_identifying_attributes(attributes, section)
      result = []
      return result if attributes.nil?
      attributes.to_h.each do |key, value|
        custom_attr = {
          :section => section,
          :name    => key,
          :value   => value,
          :source  => "kubernetes"
        }
        result << custom_attr
      end
      result
    end

    def parse_conditions(entity)
      conditions = entity.status.conditions
      conditions.to_a.collect do |condition|
        {
          :name                 => condition.type,
          :status               => condition.status,
          :last_heartbeat_time  => condition.lastHeartbeatTime,
          :last_transition_time => condition.lastTransitionTime,
          :reason               => condition.reason,
          :message              => condition.message
        }
      end
    end

    def parse_container_definition(container_def, pod_id)
      new_result = {
        :ems_ref           => "#{pod_id}_#{container_def.name}_#{container_def.image}",
        :name              => container_def.name,
        :image             => container_def.image,
        :image_pull_policy => container_def.imagePullPolicy,
        :command           => container_def.command ? Shellwords.join(container_def.command) : nil,
        :memory            => container_def.memory,
         # https://github.com/GoogleCloudPlatform/kubernetes/blob/0b801a91b15591e2e6e156cf714bfb866807bf30/pkg/api/v1beta3/types.go#L815
        :cpu_cores         => container_def.cpu.to_f / 1000,
        :capabilities_add  => container_def.securityContext.try(:capabilities).try(:add).to_a.join(','),
        :capabilities_drop => container_def.securityContext.try(:capabilities).try(:drop).to_a.join(','),
        :privileged        => container_def.securityContext.try(:privileged),
        :run_as_user       => container_def.securityContext.try(:runAsUser),
        :run_as_non_root   => container_def.securityContext.try(:runAsNonRoot),
        :security_context  => parse_security_context(container_def.securityContext)
      }
      ports = container_def.ports
      new_result[:container_port_configs] = Array(ports).collect do |port_entry|
        parse_container_port_config(port_entry, pod_id, container_def.name)
      end
      env = container_def.env
      new_result[:container_env_vars] = Array(env).collect do |env_var|
        parse_container_env_var(env_var)
      end

      new_result
    end

    def parse_container(container, pod_id)
      h = {
        :type            => 'ManageIQ::Providers::Kubernetes::ContainerManager::Container',
        :ems_ref         => "#{pod_id}_#{container.name}_#{container.image}",
        :name            => container.name,
        :restart_count   => container.restartCount,
        :backing_ref     => container.containerID,
        :container_image => parse_container_image(container.image, container.imageID)
      }
      state_attributes = parse_container_state container.lastState
      state_attributes.each { |key, val| h[key.to_s.prepend('last_').to_sym] = val } if state_attributes
      h.merge! parse_container_state container.state
    end

    def parse_container_state(state_hash)
      return if state_hash.to_h.empty?
      res = {}
      # state_hash key is the state and value are attributes e.g 'running': {...}
      (state, state_info), = state_hash.to_h.to_a
      %w(finishedAt startedAt).each do |iso_date|
        state_info[iso_date] = parse_date state_info[iso_date]
      end
      res[:state] = state
      %w(reason started_at finished_at exit_code signal message).each do |attr|
        res[attr.to_sym] = state_info[attr.camelize(:lower)]
      end
      res
    end

    def parse_date(date)
      date.nil? ? nil : DateTime.iso8601(date)
    end

    def parse_container_image(image, imageID)
      container_image, container_image_registry = parse_image_name(image, imageID)
      host_port = nil

      unless container_image_registry.nil?
        host_port = "#{container_image_registry[:host]}:#{container_image_registry[:port]}"

        stored_container_image_registry = @data_index.fetch_path(
          :container_image_registry, :by_host_and_port,  host_port)
        if stored_container_image_registry.nil?
          @data_index.store_path(
            :container_image_registry, :by_host_and_port, host_port, container_image_registry)
          stored_container_image_registry = container_image_registry
        end
      end

      stored_container_image = @data_index.fetch_path(
        :container_image, :by_ref_and_registry_host_port,  "#{host_port}:#{container_image[:image_ref]}")

      if stored_container_image.nil?
        @data_index.store_path(
          :container_image, :by_ref_and_registry_host_port,
          "#{host_port}:#{container_image[:image_ref]}", container_image)
        stored_container_image = container_image
      end

      stored_container_image[:container_image_registry] = stored_container_image_registry
      stored_container_image
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

    def parse_container_env_var(env_var)
      {
        :name       => env_var.name,
        :value      => env_var.value,
        :field_path => env_var.valueFrom.try(:fieldRef).try(:fieldPath)
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

    def parse_image_name(image, image_ref)
      parts = %r{
        \A
          (?:(?:(?<host>[^\.:\/]+\.[^\.:\/]+)|(?:(?<host2>[^:\/]+)(?::(?<port>\d+))))\/)?
          (?<name>(?:[^:\/@]+\/)*[^\/:@]+)
          (?:(?::(?<tag>.+))|(?:\@(?<digest>.+)))?
        \z
      }x.match(image)

      [
        {
          :name      => parts[:name],
          :tag       => parts[:tag],
          :digest    => parts[:digest],
          :image_ref => image_ref,
        },
        (parts[:host] || parts[:host2]) && {
          :name => parts[:host] || parts[:host2],
          :host => parts[:host] || parts[:host2],
          :port => parts[:port],
        },
      ]
    end

    def parse_security_context(security_context)
      return if security_context.nil?
      {
        :se_linux_level => security_context.seLinuxOptions.try(:level),
        :se_linux_user  => security_context.seLinuxOptions.try(:user),
        :se_linux_role  => security_context.seLinuxOptions.try(:role),
        :se_linux_type  => security_context.seLinuxOptions.try(:type)
      }
    end
  end
end
