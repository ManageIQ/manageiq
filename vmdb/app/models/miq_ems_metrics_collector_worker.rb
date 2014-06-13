class MiqEmsMetricsCollectorWorker < MiqQueueWorkerBase
  include PerEmsTypeWorkerMixin

  self.required_roles = ["ems_metrics_collector"]

  def self.normalized_type
    @normalized_type ||= "ems_metrics_collector_worker"
  end

  def self.validate_config_settings(configuration = VMDB::Config.new("vmdb"))
    super

    old_path = [:workers, :worker_base, :queue_worker_base, :perf_collector_worker]
    new_path = [:workers, :worker_base, :queue_worker_base, :ems_metrics_collector_worker]
    configuration.merge_from_template_if_missing(*new_path)

    new_collector_worker_settings = configuration.config.fetch_path(*new_path)
    old_collector_worker_settings = configuration.config.fetch_path(*old_path)
    unless old_collector_worker_settings.nil?
      # The subclass list should be discoverable and not hardcoded here
      subclasses = %w{amazon redhat vmware openstack}.collect { |k| "ems_metrics_collector_worker_#{k}".to_sym }
      $log.info("MIQ(#{self.name}) Migrating Settings")
      defaults = old_collector_worker_settings
      subclasses.each { |subclass_key| defaults.delete(subclass_key)}
      new_collector_worker_settings = { :defaults => defaults }
      configuration.config.store_path(new_path, new_collector_worker_settings)

      subclasses.each { |subclass_key| configuration.merge_from_template_if_missing(*(new_path + [subclass_key])) }
      configuration.config.delete_path(*old_path)
    end
  end

end
