class MiqEventCatcherOpenstack < MiqEventCatcher
  def self.ems_class
    EmsOpenstack
  end

  def self.all_valid_ems_in_zone
    # Overridden to gate the execution of OpenstackEventMonitor in cases where
    # the qpid-cpp-client-devel package is not available.  See
    # PerEmsWorkerMixin#sync_workers and PerEmsWorkerMixin#start_workers to
    # understand the overall flow when starting Event Catchers.
    require 'openstack/openstack_event_monitor'
    super.select do |ems|
      ems.event_monitor_available?.tap do |available|
        $log.info("MIQ(#{self.name}.#{__method__}) Event Monitor unavailable for #{ems.name}.  Check log history for more details.") unless available
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
