module EmsRefresh::Parsers
  class Kubernetes
    def self.ems_inv_to_hashes(inventory)
      new.ems_inv_to_hashes(inventory)
    end

    def initialize
      @data = {}
    end

    def ems_inv_to_hashes(inventory)
      get_nodes(inventory)
      get_services(inventory)
      get_pods(inventory)
      EmsRefresh.log_inv_debug_trace(@data, "data:")
      @data
    end

    def get_nodes(inventory)
      process_collection(inventory["node"], :container_nodes) { |n| parse_node(n) }
    end

    def get_services(inventory)
      process_collection(inventory["service"], :container_services) { |s| parse_service(s) }
    end

    def get_pods(inventory)
      process_collection(inventory["pod"], :container_groups) { |n| parse_pod(n) }
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
      # TODO, add more properties such as resources
      new_result
    end

    def parse_service(service)
      new_result = parse_base_item(service)
      new_result.merge!(
        :port             => service.spec.port,
        :protocol         => service.spec.protocol,
        :portal_ip        => service.spec.portalIP,
        :container_port   => service.spec.containerPort,
        :namespace        => service.metadata.instance_values["table"][:namespace],
        :session_affinity => service.spec.sessionAffinity,

        :labels           => parse_labels(service)
      )
      new_result
    end

    def parse_pod(pod)
      # pod in kubernetes is container group in manageiq
      new_result = parse_base_item(pod)
      new_result.merge!(
        # namespace is overriden in more_core_extensions and hence needs a non method access
        :namespace      => pod.metadata.instance_values["table"][:namespace],
        # workaround due to https://github.com/GoogleCloudPlatform/kubernetes/issues/3607
        :restart_policy => pod.spec.restartPolicy.to_h.keys.first.to_s,
        :dns_policy     => pod.spec.dnsPolicy
      )
      # TODO, map volumes
      # TODO, podIP
      containers = pod.spec.containers
      new_result[:container_definitions] = containers.collect do |container_def|
        parse_container_definition(container_def, pod.metadata.uid)
      end

      # container instances

      unless pod.status.info.nil?
        new_result[:containers] = pod.status.info.to_h.collect do |container_name, container|
          parse_container(container, container_name, pod.metadata.uid)
        end
      end

      new_result[:labels] = parse_labels(pod)
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

    def parse_container_definition(container_def, pod_id)
      new_result = {
        :ems_ref           => "#{pod_id}_#{container_def["name"]}_#{container_def["image"]}",
        :name              => container_def["name"],
        :image             => container_def["image"],
        :image_pull_policy => container_def["imagePullPolicy"],
        :memory            => container_def["memory"],
         # https://github.com/GoogleCloudPlatform/kubernetes/blob/0b801a91b15591e2e6e156cf714bfb866807bf30/pkg/api/v1beta3/types.go#L815
        :cpu_cores         => container_def["cpu"].to_f / 1000
      }
      ports = container_def["ports"]
      new_result[:container_port_configs] = ports.collect do |port_entry|
        parse_container_port_config(port_entry, pod_id, container_def["name"])
      end
      new_result
    end

    def parse_container(container, container_name, pod_id)
      {
        :ems_ref       => "#{pod_id}_#{container_name}_#{container["image"]}",
        :name          => container_name,
        :image         => container["image"],
        :restart_count => container["restartCount"],
        :container_id  => container["containerID"]
      }
      # TODO, state
    end

    def parse_container_port_config(port_config, pod_id, container_name)
      {
        :ems_ref   => "#{pod_id}_#{container_name}_#{port_config["containerPort"]}_#{port_config["hostPort"]}_#{port_config["protocol"]}",
        :port      => port_config["containerPort"],
        :host_port => port_config["hostPort"],
        :protocol  => port_config["protocol"]
      }
    end

    private

    def parse_base_item(item)
      {
        :ems_ref            => item.metadata.uid,
        :name               => item.metadata.name,
        :creation_timestamp => item.metadata.creationTimestamp,
        :resource_version   => item.metadata.resourceVersion
      }
    end
  end
end
