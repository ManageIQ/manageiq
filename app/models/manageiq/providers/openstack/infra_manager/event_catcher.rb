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
end
