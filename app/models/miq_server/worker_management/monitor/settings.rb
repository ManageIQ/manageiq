module MiqServer::WorkerManagement::Monitor::Settings
  extend ActiveSupport::Concern

  included do
    attr_reader :child_worker_settings
    attr_reader :worker_monitor_settings
  end

  def reload_worker_settings
    sync_config
    reset_queue_messages
    notify_workers_of_config_change(Time.now.utc)
    MiqWorkerType.worker_classes.each(&:reload_worker_settings)
  end

  def sync_config
    sync_worker_monitor_settings
    sync_child_worker_settings
    $log.log_hashes(@worker_monitor_settings)
  end

  def sync_child_worker_settings
    child_worker_settings = {}
    MiqWorkerType.worker_classes.each do |worker_class|
      child_worker_settings[worker_class.settings_name] = worker_class.worker_settings
      child_worker_settings[worker_class.settings_name].merge!(get_additional_settings(worker_class.worker_settings_paths)) unless worker_class.worker_settings_paths.empty?
      check_settings_diff(child_worker_settings[worker_class.settings_name], worker_class) unless worker_class.rails_worker?
    end

    @child_worker_settings = child_worker_settings
  end

  def sync_worker_monitor_settings
    @worker_monitor_settings = ::Settings.server.worker_monitor.to_hash
    @worker_monitor_settings.keys.each do |k|
      @worker_monitor_settings[k] = @worker_monitor_settings[k].to_i_with_method if @worker_monitor_settings[k].respond_to?(:to_i_with_method)
    end
    @worker_monitor_settings
  end

  def get_worker_poll(worker)
    @child_worker_settings[worker.class.settings_name][:poll]
  end

  def get_time_threshold(worker)
    settings = @child_worker_settings[worker.class.settings_name]

    heartbeat_timeout  = settings[:heartbeat_timeout] || Workers::MiqDefaults.heartbeat_timeout
    starting_timeout   = settings[:starting_timeout] || Workers::MiqDefaults.starting_timeout

    return starting_timeout if MiqWorker::STATUSES_STARTING.include?(worker.status)

    if worker.kind_of?(MiqQueueWorkerBase)
      timeout = worker.current_timeout
      return (get_worker_poll(worker) + timeout) unless timeout.nil?
    end

    heartbeat_timeout
  end

  def get_memory_threshold(worker)
    @child_worker_settings[worker.class.settings_name][:memory_threshold]
  end

  def get_additional_settings(worker_settings_paths)
    additional_settings = {}
    worker_settings_paths.to_a.each do |settings_path|
      additional_settings.store_path(settings_path, Settings.to_hash.dig(*settings_path))
    end

    additional_settings
  end

  private

  def check_settings_diff(new_settings, worker_class)
    return if @child_worker_settings.nil?

    old_settings = @child_worker_settings[worker_class.settings_name]

    worker_class.restart_workers if Vmdb::Settings::HashDiffer.changes(new_settings, old_settings).any?
  end
end
