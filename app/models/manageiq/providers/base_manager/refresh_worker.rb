class ManageIQ::Providers::BaseManager::RefreshWorker < MiqQueueWorkerBase
  require_nested :Runner

  include PerEmsWorkerMixin

  self.required_roles = "ems_inventory"

  def friendly_name
    @friendly_name ||= begin
      ems = ext_management_system
      if ems.nil?
        queue_name.titleize
      else
        _("Refresh Worker for %{table}: %{name}") % {:table => ui_lookup(:table => "ext_management_systems"),
                                                     :name  => ems.name}
      end
    end
  end

  def self.ems_class
    parent
  end

  def self.normalized_type
    @normalized_type ||= "ems_refresh_worker"
  end

  def self.validate_config_settings(configuration = VMDB::Config.new("vmdb"))
    super

    path = [:workers, :worker_base, :queue_worker_base, :ems_refresh_worker]

    refresh_worker_settings = configuration.fetch_with_fallback(*path)
    unless refresh_worker_settings.key?(:defaults)
      subclasses = ExtManagementSystem.types.collect { |k| "ems_refresh_worker_#{k}".to_sym }
      _log.info('Migrating Settings')
      defaults = refresh_worker_settings
      subclasses.each { |subclass_key| defaults.delete(subclass_key) }
      refresh_worker_settings = {:defaults => defaults}
      configuration.config.store_path(path, refresh_worker_settings)

      subclasses.each { |subclass_key| configuration.merge_from_template_if_missing(*(path + [subclass_key])) }
    end
  end
end
