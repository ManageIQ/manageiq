module MiqServer::WorkerManagement::Monitor::Kubernetes
  extend ActiveSupport::Concern
  attr_accessor :pod_resource_version

  def current_pods
    # TODO: Add mutex around access
    @current_pods ||= begin
      # The first call to current_pods will return an empty hash since the newly created collector thread hasn't collected anything yet.
      collector_thread
      {}
    end
  end

  def cleanup_failed_deployments
    # TODO: We should have a list of worker deployments we'll delete to avoid accidentally killing pg/memcached/orchestrator
    # See ContainerOrchestrator#get_pods
    failed_deployments.each do |failed|
      orchestrator.delete_deployment(failed)
    end
  end

  def failed_deployments(restart_count = 5)
    # TODO: This logic might flag deployments that are hitting memory/cpu limits or otherwise not really 'failed'
    current_pods.select { |name, h| h.fetch(:last_state_terminated) && h.fetch(:container_restarts, 0) > restart_count }.collect { |name, h| h[:label_name] }
  end

  private
  def collector_thread
    # TODO: Ensure thread exceptions kill the thread and a new thread is created
    @collector_thread ||= Thread.new { pod_collector }
  end

  def orchestrator
    @orchestrator ||= ContainerOrchestrator.new
  end

  def pod_collector
    # TODO: To ensure we're in sync, we might want to break out of the watch, reset the current_pods and run this again
    collect_initial_pods
    watch_for_pod_events
  end

  def collect_initial_pods
    pods = orchestrator.get_pods
    pods.each { |p| save_pod(p) }
    self.pod_resource_version = pods.resourceVersion || 0
  end

  def watch_for_pod_events
    orchestrator.watch_pods(self.pod_resource_version) do |event|
      case event.type.downcase
      when "added", "modified"
        save_pod(event.object)
      when "deleted"
        delete_pod(event.object)
      when "error"
        # TODO
      end
    end
  end

  def save_pod(pod)
    # TODO: consider a more nuanced data structure if we're going to start using current_pods from sync_workers
    name = pod.metadata.name
    current_pods[name] ||= {}
    current_pods[name][:label_name]            = pod.metadata.labels.name
    current_pods[name][:last_state_running]    = pod.status.containerStatuses.all? { |cs| !!cs.state.running }
    current_pods[name][:started_at]            = pod.status.containerStatuses.collect {|cs| cs.state.running && cs.state.running.startedAt }.compact
    current_pods[name][:last_state_terminated] = pod.status.containerStatuses.any? { |cs| !!cs.lastState.terminated }
    current_pods[name][:container_restarts]    = pod.status.containerStatuses.inject(0) { |sum, cs| sum += cs.restartCount if cs.lastState.terminated; sum }
  end

  def delete_pod(pod)
    current_pods.delete(pod.metadata.name)
  end
end
