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

  def open_alert_criteria
    # Use "tagQuery" => "type==node AND not seen_by" when that becomes available in HAWKULAR API
    {"tags" => "type|*", "thin" => true, "statuses" => 'OPEN,ACKNOWLEDGED'}
  end

  def resolved_alert_criteria
    # Use "tagQuery" => "type==node AND not resolved_seen_by" when that becomes available in HAWKULAR API
    {"tags" => "type|*", "thin" => true, "statuses" => 'RESOLVED'}
  end

  def alert_tenants
    ManageIQ::Providers::Hawkular::DatawarehouseManager::EventCatcher.worker_settings[:alertable_tenants]
  end

  def post_fetch(alerts)
    # Tag with seen_by => server_UUID when that becomes available through the HAWKULAR API
  end
end
