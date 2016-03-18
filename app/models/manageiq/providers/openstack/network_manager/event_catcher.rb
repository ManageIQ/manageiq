class ManageIQ::Providers::Openstack::NetworkManager::EventCatcher < ::MiqEventCatcher
  require_nested :Runner

  def self.ems_class
    ManageIQ::Providers::Openstack::NetworkManager
  end

  def self.settings_name
    :event_catcher_openstack_network
  end

  def self.all_valid_ems_in_zone
    require 'openstack/openstack_event_monitor'
    super.select do |ems|
      ems.event_monitor_available?.tap do |available|
        _log.info("Event Monitor unavailable for #{ems.name}.  Check log history for more details.") unless available
      end
    end
  end

  def self.validate_config_settings(config = VMDB::Config.new("vmdb"))
    super

    # make sure that new configurations for :topics and :duration are loaded
    config.merge_from_template_if_missing(:workers, :worker_base, :event_catcher, :event_catcher_openstack_network, :topics)
    config.merge_from_template_if_missing(:workers, :worker_base, :event_catcher, :event_catcher_openstack_network, :duration)
    config.merge_from_template_if_missing(:workers, :worker_base, :event_catcher, :event_catcher_openstack_network, :capacity)
    config.merge_from_template_if_missing(:workers, :worker_base, :event_catcher, :event_catcher_openstack_network, :amqp_port)
  end
end
