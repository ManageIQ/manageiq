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
    {}
  end

  def alert_tenants
    []
  end

  def post_fetch(alerts)
    # Tag with seen_by => server_UUID when that becomes available through the HAWKULAR API
  end
end
