class ManageIQ::Providers::Hawkular::DatawarehouseManager::EventCatcher::Runner <
  ManageIQ::Providers::BaseManager::EventCatcher::Runner

  include ManageIQ::Providers::Hawkular::Common::EventCatcher::RunnerMixin

  def initialize(cfg = {})
    super
  end

  def self.log_handle
    $datawarehouse_log
  end

  def self.event_monitor_class
    ManageIQ::Providers::Hawkular::DatawarehouseManager::EventCatcher::Stream
  end

  private

  def whitelist?(_event)
    true # we collect event by tags, see stream
  end

  def event_to_hash(event, current_ems_id)
    {}
  end
end
