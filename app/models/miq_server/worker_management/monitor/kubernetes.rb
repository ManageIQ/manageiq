module MiqServer::WorkerManagement::Monitor::Kubernetes
  extend ActiveSupport::Concern

  included do
    cattr_accessor :current_pods
    self.current_pods = Concurrent::Hash.new

    class_attribute :current_deployments
    self.current_deployments = Concurrent::Hash.new

    attr_accessor :deployments_monitor_thread, :pods_monitor_thread
  end

  def cleanup_failed_deployments
    delete_failed_deployments
  end

  def failed_deployments(restart_count = 5)
    # TODO: This logic might flag deployments that are hitting memory/cpu limits or otherwise not really 'failed'
    current_pods.values.select { |h| h[:last_state_terminated] && h.fetch(:container_restarts, 0) > restart_count }.collect { |h| h[:label_name] }
  end

  def sync_deployment_settings
    checked_deployments = Set.new
    podified_miq_workers.each do |worker|
      next if checked_deployments.include?(worker.worker_deployment_name)

      if deployment_resource_constraints_changed?(worker)
        _log.info("Constraints changed, patching deployment: [#{worker.worker_deployment_name}]")
        worker.patch_deployment
      end
      checked_deployments << worker.worker_deployment_name
    end
  end

  def podified_miq_workers
    # Cockpit is a threaded worker in the orchestrator that spins off a process it monitors and isn't a pod worker.
    miq_workers.where.not(:type => %w[MiqCockpitWsWorker])
  end

  def deployment_resource_constraints_changed?(worker)
    return false unless Settings.server.worker_monitor.enforce_resource_constraints

    container = current_deployments.fetch_path(worker.worker_deployment_name, :spec, :template, :spec, :containers).try(:first)
    current_constraints = container.try(:fetch, :resources, nil) || {}
    desired_constraints = worker.resource_constraints
    constraints_changed?(current_constraints, desired_constraints)
  end

  def constraints_changed?(current, desired)
    if current.present? && desired.present?
      !cpu_value_eql?(current.fetch_path(:requests, :cpu), desired.fetch_path(:requests, :cpu)) ||
        !cpu_value_eql?(current.fetch_path(:limits, :cpu), desired.fetch_path(:limits, :cpu)) ||
        !mem_value_eql?(current.fetch_path(:requests, :memory), desired.fetch_path(:requests, :memory)) ||
        !mem_value_eql?(current.fetch_path(:limits, :memory), desired.fetch_path(:limits, :memory))
    else
      # current, no desired    => changed
      # no current, desired    => changed
      # no current, no desired => unchanged
      current.blank? ^ desired.blank?
    end
  end

  private

  def cpu_value_eql?(current, desired)
    # Convert to millicores if not already converted: "1" -> 1000; "1000m" -> 1000
    current = current.to_s[-1] == "m" ? current.to_f : current.to_f * 1000
    desired = desired.to_s[-1] == "m" ? desired.to_f : desired.to_f * 1000
    current == desired
  end

  def mem_value_eql?(current, desired)
    current.try(:iec_60027_2_to_i) == desired.try(:iec_60027_2_to_i)
  end

  def start_kube_monitor(resource = :pods)
    require 'http'
    Thread.new do
      _log.info("Started new #{resource} monitor thread of #{Thread.list.length} total")
      begin
        send("monitor_#{resource}")
      rescue HTTP::ConnectionError => e
        _log.error("Exiting #{resource} monitor thread due to [#{e.class.name}]: #{e}")
      rescue => e
        _log.error("Exiting #{resource} monitor thread after uncaught error")
        _log.log_backtrace(e)
      end
    end
  end

  def ensure_kube_monitors_started
    [:deployments, :pods].each do |resource|
      getter = "#{resource}_monitor_thread"
      thread = send(getter)
      if thread.nil? || !thread.alive?
        if !thread.nil? && thread.status.nil?
          dead_thread = thread
          send("#{getter}=", nil)
          _log.info("Waiting for the #{getter} Monitor Thread to exit...")
          dead_thread.join
        end

        send("#{getter}=", start_kube_monitor(resource))
      end
    end
  end

  def delete_failed_deployments
    failed_deployments.each do |failed|
      orchestrator.delete_deployment(failed)
    end
  end

  def orchestrator
    @orchestrator ||= ContainerOrchestrator.new
  end

  def monitor_deployments
    loop do
      current_deployments.clear
      resource_version = collect_initial(:deployments)

      watch_for_events(:deployments, resource_version)
    end
  end

  def monitor_pods
    loop do
      current_pods.clear
      resource_version = collect_initial(:pods)

      # watch_for_events doesn't return unless an error caused us to break out of it, so we'll start over again
      watch_for_events(:pods, resource_version)
    end
  end

  def collect_initial(resource = :pods)
    objects = orchestrator.send("get_#{resource}")
    objects.each { |p| send("save_#{resource.to_s.singularize}", p) }
    objects.resourceVersion
  end

  def watch_for_events(resource, resource_version)
    orchestrator.send("watch_#{resource}", resource_version).each do |event|
      case event.type.downcase
      when "added", "modified"
        send("save_#{resource.to_s.singularize}", event.object)
      when "deleted"
        send("delete_#{resource.to_s.singularize}", event.object)
      when "error"
        if (status = event.object)
          # ocp 3 appears to return 'ERROR' watch events with the object containing the 410 code and "Gone" reason like below:
          # #<Kubeclient::Resource type="ERROR", object={:kind=>"Status", :apiVersion=>"v1", :metadata=>{}, :status=>"Failure", :message=>"too old resource version: 199900 (27177196)", :reason=>"Gone", :code=>410}>
          log_resource_error_event(status.code, status.message, status.reason)
        end

        break
      end
    end
  end

  def log_resource_error_event(code, message, reason)
    _log.warn("Restarting watch_for_events due to error: [#{code} #{reason}], [#{message}]")
  end

  def save_deployment(deployment)
    name = deployment.metadata.name
    new_hash = Concurrent::Hash.new
    new_hash[:spec] = deployment.spec.to_h
    current_deployments[name] ||= new_hash
    current_deployments[name].merge!(new_hash)
  end

  def delete_deployment(deployment)
    current_deployments.delete(deployment.metadata.name)
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
