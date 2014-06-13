class MiqEventCatcher < MiqWorker
  include PerEmsWorkerMixin

  self.required_roles = ["event"]

  def friendly_name
    @friendly_name ||= begin
      ems = self.ext_management_system
      name = ems.nil? ? self.queue_name.titleize : "Event Monitor for #{ui_lookup(:table=>"ext_management_systems")}: #{ems.name}"
    end
  end

  def self.normalized_type
    @normalized_type ||= "event_catcher"
  end

  def self.validate_config_settings(configuration = VMDB::Config.new("vmdb"))
    super

    path = [:workers, :worker_base, :event_catcher]
    configuration.merge_from_template_if_missing(*path)

    ec_settings = configuration.config.fetch_path(*path)
    unless ec_settings.has_key?(:defaults)
      subclasses = %w{redhat vmware openstack}.collect { |k| "event_catcher_#{k}".to_sym }
      $log.info("MIQ(#{self.name}) Migrating Settings")
      defaults = ec_settings
      subclasses.each { |subclass_key| defaults.delete(subclass_key)}
      ec_settings = { :defaults => defaults }
      configuration.config.store_path(path, ec_settings)

      subclasses.each { |subclass_key| configuration.merge_from_template_if_missing(*(path + [subclass_key])) }
    end
  end
end
