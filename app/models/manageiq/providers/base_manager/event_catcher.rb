class ManageIQ::Providers::BaseManager::EventCatcher < MiqWorker
  require_nested :Runner

  include PerEmsWorkerMixin

  self.required_roles = ["event"]

  def friendly_name
    @friendly_name ||= begin
      ems = ext_management_system
      if ems.nil?
        queue_name.titleize
      else
        _("Event Monitor for %{table}: %{name}") % {:table => ui_lookup(:table => "ext_management_systems"),
                                                    :name  => ems.name}
      end
    end
  end

  def self.ems_class
    parent
  end

  def self.validate_config_settings(configuration = VMDB::Config.new("vmdb"))
    super

    path = [:workers, :worker_base, :event_catcher]

    ec_settings = configuration.fetch_with_fallback(*path)
    unless ec_settings.key?(:defaults)
      subclasses = %w(redhat vmware openstack).collect { |k| "event_catcher_#{k}".to_sym }
      _log.info("Migrating Settings")
      defaults = ec_settings
      subclasses.each { |subclass_key| defaults.delete(subclass_key) }
      ec_settings = {:defaults => defaults}
      configuration.config.store_path(path, ec_settings)

      subclasses.each { |subclass_key| configuration.merge_from_template_if_missing(*(path + [subclass_key])) }
    end
  end
end
