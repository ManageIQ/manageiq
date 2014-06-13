module MiqServer::WorkerManagement::Monitor::Settings
  extend ActiveSupport::Concern

  included do
    attr_reader :child_worker_settings
    attr_reader :worker_monitor_settings
  end

  def sync_child_worker_settings
    @child_worker_settings = {}
    self.class.monitor_class_names.each do |class_name|
      c = class_name.constantize
      @child_worker_settings[c.corresponding_helper] = c.worker_settings
    end
    @child_worker_settings
  end

  def sync_worker_monitor_settings
    @worker_monitor_settings = @vmdb_config.config[:server][:worker_monitor]
    @worker_monitor_settings.keys.each do |k|
      @worker_monitor_settings[k] = @worker_monitor_settings[k].to_i_with_method if @worker_monitor_settings[k].respond_to?(:to_i_with_method)
    end
    @worker_monitor_settings
  end

  def get_worker_poll(worker)
    @child_worker_settings[worker.class.corresponding_helper][:poll]
  end

  def get_time_threshold(worker)
    settings = @child_worker_settings[worker.class.corresponding_helper]

    heartbeat_timeout  = settings[:heartbeat_timeout] ||  2.minutes
    starting_timeout   = settings[:starting_timeout]  || 10.minutes

    return starting_timeout if MiqWorker::STATUSES_STARTING.include?(worker.status)

    if worker.kind_of?(MiqQueueWorkerBase)
      timeout = worker.current_timeout
      return (self.get_worker_poll(worker) + timeout) unless timeout.nil?
    end

    return heartbeat_timeout
  end

  def get_restart_interval(worker)
    @child_worker_settings[worker.class.corresponding_helper][:restart_interval]
  end

  def get_memory_threshold(worker)
    @child_worker_settings[worker.class.corresponding_helper][:memory_threshold]
  end
end
