class MiqEmsMetricsProcessorWorker < MiqQueueWorkerBase
  self.required_roles       = ["ems_metrics_processor"]
  self.default_queue_name   = "ems_metrics_processor"

  def friendly_name
    @friendly_name ||= "C&U Metrics Processor"
  end

  def self.validate_config_settings(configuration = VMDB::Config.new("vmdb"))
    super

    old_path = [:workers, :worker_base, :queue_worker_base, :perf_processor_worker]
    new_path = [:workers, :worker_base, :queue_worker_base, :ems_metrics_processor_worker]

    processor_worker_settings = configuration.config.fetch_path(*old_path)
    unless processor_worker_settings.nil?
      $log.info("MIQ(#{self.name}) Migrating Settings")
      configuration.config.delete_path(*old_path)
      configuration.config.store_path(new_path, processor_worker_settings)
    end
  end

end
