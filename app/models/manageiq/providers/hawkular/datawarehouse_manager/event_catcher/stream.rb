class ManageIQ::Providers::Hawkular::DatawarehouseManager::EventCatcher::Stream
  include ManageIQ::Providers::Hawkular::Common::EventCatcher::StreamMixin

  def initialize(ems)
    @ems               = ems
    @collecting_events = false
  end

  private

  def log_handle
    $datawarehouse_log
  end

  def hawkular_alert_criteria
    # Use "tagQuery" => "type==node AND not seen_by" when that becomes available in HAWKULAR API
    {"tags" => "type|*", "thin" => true}
  end

  def alert_tenants
    ManageIQ::Providers::Hawkular::DatawarehouseManager::EventCatcher.worker_settings[:alertable_tenants]
  end

  def seen_alerts_tags
    ["seen_by#{MiqServer.my_server.id}|true"]
  end
end
