module Api
  class AlertsStatusesController < BaseController
    def update
      if @req.action == "providers_alerts"
        providers_alerts_resource
      else
        super
      end
    end

    def providers_alerts_resource
      payload = {"providers" => []}
      ExtManagementSystem.all.each do |provider|
        payload["providers"] << {"name" => provider.name,
                                 "type" => provider.class.to_s,
                                 "id"   => provider.id}.merge!(add_providers_alerts(provider))
      end
      render_resource :alertes_statuses, payload
    end

    private

    def add_providers_alerts(provider)
      result = {"alerts_types" => {}}
      MiqAlertStatus::SEVERITY_LEVELS.each do |severity|
        result["alerts_types"][severity] = {"alerts" => alerts_by_severity(provider, severity)}
      end
      result
    end

    def alerts_by_severity(provider, severity)
      result = []
      provider.miq_alert_statuses.each do |alert_status|
        next unless alert_status.miq_alert.severity == severity
        alert = {
          "evaluated_on"  => alert_status.evaluated_on,
          "link_text"     => alert_status.miq_alert.link_text,
          "node_hostname" => alert_status.resource.name,
          "description"   => alert_status.miq_alert.description
        }
        if alert_status.user
          alert["asignee_id"] = alert_status.user.id
          alert["asignee_name"] = alert_status.user.name
          alert["asignee_ack_text"] = alert_status.asignee_ack_text
        end
        result << alert
      end
      result
    end
  end
end
