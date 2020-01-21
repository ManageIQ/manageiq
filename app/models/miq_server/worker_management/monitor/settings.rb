module MiqServer::WorkerManagement::Monitor::Settings
  extend ActiveSupport::Concern

  included do
    attr_reader :child_worker_settings
    attr_reader :worker_monitor_settings
  end

  def sync_child_worker_settings
    @child_worker_settings = {}
    MiqWorkerType.worker_class_names.each do |class_name|
      c = class_name.constantize
      @child_worker_settings[c.settings_name] = c.worker_settings
    end
    @child_worker_settings
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
end
