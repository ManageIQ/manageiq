class MiqEmsRefreshWorker < MiqQueueWorkerBase
  include PerEmsWorkerMixin

  self.required_roles = "ems_inventory"

  def friendly_name
    @friendly_name ||= begin
      ems = self.ext_management_system
      name = ems.nil? ? self.queue_name.titleize : "Refresh Worker for #{ui_lookup(:table => "ext_management_systems")}: #{ems.name}"
    end
  end

  def self.normalized_type
    @normalized_type ||= "ems_refresh_worker"
  end

  def self.validate_config_settings(configuration = VMDB::Config.new("vmdb"))
    super

    path = [:workers, :worker_base, :queue_worker_base, :ems_refresh_worker]
    configuration.merge_from_template_if_missing(*path)

    refresh_worker_settings = configuration.config.fetch_path(*path)
    unless refresh_worker_settings.has_key?(:defaults)
      subclasses = %w{amazon microsoft redhat vmware}.collect { |k| "ems_refresh_worker_#{k}".to_sym }
      $log.info("MIQ(#{self.name}) Migrating Settings")
      defaults = refresh_worker_settings
      subclasses.each { |subclass_key| defaults.delete(subclass_key)}
      refresh_worker_settings = { :defaults => defaults }
      configuration.config.store_path(path, refresh_worker_settings)

      subclasses.each { |subclass_key| configuration.merge_from_template_if_missing(*(path + [subclass_key])) }
    end
  end

end
