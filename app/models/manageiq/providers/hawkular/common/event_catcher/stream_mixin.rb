module ManageIQ::Providers::Hawkular::Common::EventCatcher::StreamMixin
  extend ActiveSupport::Concern

  def start
    @collecting_events = true
  end

  def stop
    @collecting_events = false
  end

  def each_batch
    while @collecting_events
      yield fetch
    end
  end

  def fetch
    new_alerts = []
    alert_tenants.each do |tenant|
      log_handle.debug "Fetching tenant [#{tenant}] events using criteria [#{hawkular_alert_criteria}]"
      new_alerts.concat(@ems.alerts_client(:tenant => tenant).list_alerts(hawkular_alert_criteria))
    end
    @ems.alerts_client(:tenant => tenant).tag(new_alerts.map(:id).uniq, seen_alerts_tag) if method(:seen_alerts_tags)
    new_alerts
  rescue => err
    log_handle.error "Error capturing alerts #{err}"
    []
  end
end
