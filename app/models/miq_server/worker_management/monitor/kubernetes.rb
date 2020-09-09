module MiqServer::WorkerManagement::Monitor::Kubernetes
  extend ActiveSupport::Concern
  attr_accessor :pod_resource_version

  included do
    cattr_accessor :current_pods
    self.current_pods = Concurrent::Hash.new
  end

  def cleanup_failed_deployments
    ensure_pod_monitor_started
    delete_failed_deployments
  end

  def failed_deployments(restart_count = 5)
    # TODO: This logic might flag deployments that are hitting memory/cpu limits or otherwise not really 'failed'
    current_pods.values.select { |h| h[:last_state_terminated] && h.fetch(:container_restarts, 0) > restart_count }.collect { |h| h[:label_name] }
  end

  private

  def start_pod_monitor
    @monitor_thread ||= Thread.new { monitor_pods }
  end

  def ensure_pod_monitor_started
    if @monitor_thread.nil? || !@monitor_thread.alive?
      if !@monitor_thread.nil? && @monitor_thread.status.nil?
        dead_thread, @monitor_thread = @monitor_thread, nil
        _log.info("Waiting for the Monitor Thread to exit...")
        dead_thread.join
      end

      start_pod_monitor
    end
  end

  def delete_failed_deployments
    # TODO: We should have a list of worker deployments we'll delete to avoid accidentally killing pg/memcached/orchestrator
    # See ContainerOrchestrator#get_pods
    failed_deployments.each do |failed|
      orchestrator.delete_deployment(failed)
    end
  end

  def orchestrator
    @orchestrator ||= ContainerOrchestrator.new
  end

  def monitor_pods
    loop do
      current_pods.clear
      collect_initial_pods

      # watch_for_pod_events doesn't return unless an error caused us to break out of it, so we'll reset and start over again
      watch_for_pod_events
    end
  end

  def collect_initial_pods
    pods = orchestrator.get_pods
    pods.each { |p| save_pod(p) }
    self.pod_resource_version = pods.resourceVersion
  end

  def watch_for_pod_events
    orchestrator.watch_pods(pod_resource_version).each do |event|
      case event.type.downcase
      when "added", "modified"
        save_pod(event.object)
      when "deleted"
        delete_pod(event.object)
      when "error"
        if status = event.object
          # ocp 3 appears to return 'ERROR' watch events with the object containing the 410 code and "Gone" reason like below:
          # #<Kubeclient::Resource type="ERROR", object={:kind=>"Status", :apiVersion=>"v1", :metadata=>{}, :status=>"Failure", :message=>"too old resource version: 199900 (27177196)", :reason=>"Gone", :code=>410}>
          log_pod_error_event(status.code, status.message, status.reason)
        end

        self.pod_resource_version = nil
        break
      end
    end
  end

  def log_pod_error_event(code, message, reason)
    _log.warn("Restarting watch_pods at resource_version 0 due to error: [#{code} #{reason}], [#{message}]")
  end

  def save_pod(pod)
    return unless pod.status.containerStatuses

    ch = Concurrent::Hash.new
    ch[:label_name]            = pod.metadata.labels.name
    ch[:last_state_terminated] = pod.status.containerStatuses.any? { |cs| cs.lastState.terminated }
    ch[:container_restarts]    = pod.status.containerStatuses.sum { |cs| cs.restartCount.to_i }

    name = pod.metadata.name
    current_pods[name] ||= ch
    current_pods[name].merge!(ch)
  end

  def delete_pod(pod)
    current_pods.delete(pod.metadata.name)
  end
end
