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
    new_alerts = fetch_criteria(open_alert_criteria)
    new_alerts.concat(fetch_criteria(resolved_alert_criteria)) if method(:resolved_alert_criteria)
    post_fetch(new_alerts)
    new_alerts
  rescue => err
    log_handle.error "Error capturing alerts #{err}"
    []
  end

  def fetch_criteria(criteria)
    new_alerts = []
    alert_tenants.each do |tenant|
      log_handle.debug "Fetching tenant [#{tenant}] alerts using criteria [#{criteria}]"
      new_alerts.concat(@ems.alerts_client(:tenant => tenant).list_alerts(criteria))
    end
    new_alerts
  end
end
