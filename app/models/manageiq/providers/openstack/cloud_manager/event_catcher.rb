class ManageIQ::Providers::Openstack::CloudManager::EventCatcher < ::MiqEventCatcher
  require_dependency 'manageiq/providers/openstack/cloud_manager/event_catcher/runner'

  def self.ems_class
    ManageIQ::Providers::Openstack::CloudManager
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
    path = [:workers, :worker_base, :event_catcher, :event_catcher_openstack, :topics]
    configuration.merge_from_template_if_missing(*path)
    path = [:workers, :worker_base, :event_catcher, :event_catcher_openstack, :duration]
    configuration.merge_from_template_if_missing(*path)
    path = [:workers, :worker_base, :event_catcher, :event_catcher_openstack, :capacity]
    configuration.merge_from_template_if_missing(*path)
    path = [:workers, :worker_base, :event_catcher, :event_catcher_openstack, :amqp_port]
    configuration.merge_from_template_if_missing(*path)
  end
end
