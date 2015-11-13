class ManageIQ::Providers::Openstack::InfraManager::EventCatcher < ::MiqEventCatcher
  require_nested :Runner

  def self.ems_class
    ManageIQ::Providers::Openstack::InfraManager
  end

  def self.settings_name
    :event_catcher_openstack_infra
  end

  def self.all_valid_ems_in_zone
    require 'openstack/openstack_event_monitor'
    super.select do |ems|
      ems.event_monitor_available?.tap do |available|
        _log.info("Event Monitor unavailable for #{ems.name}.  Check log history for more details.") unless available
      end
    end
  end

  def self.validate_config_settings(configuration = VMDB::Config.new("vmdb"))
    super

    # make sure that new configurations for :topics and :duration are loaded
    path = [:workers, :worker_base, :event_catcher, :event_catcher_openstack_infra, :topics]
    configuration.merge_from_template_if_missing(*path)
    path = [:workers, :worker_base, :event_catcher, :event_catcher_openstack_infra, :duration]
    configuration.merge_from_template_if_missing(*path)
    path = [:workers, :worker_base, :event_catcher, :event_catcher_openstack_infra, :capacity]
    configuration.merge_from_template_if_missing(*path)
    path = [:workers, :worker_base, :event_catcher, :event_catcher_openstack_infra, :amqp_port]
    configuration.merge_from_template_if_missing(*path)
  end
end
