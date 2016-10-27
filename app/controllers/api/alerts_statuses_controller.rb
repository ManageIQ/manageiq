module Api
  class AlertsStatusesController < BaseController
    include Subcollections::AlertStatusStates

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
        payload["providers"] << {
          "environment" => "production",
          "name"        => provider.name,
          "type"        => provider.class.to_s,
          "id"          => provider.id}.merge("alerts" => alerts_and_states(provider))
      end
      render_resource :alertes_statuses, payload
    end

    private

    def alerts_and_states(provider)
      result = []
      provider.miq_alert_statuses.each do |alert_status|
        alert = {
          "evaluated_on"  => alert_status.evaluated_on,
          "link_text"     => alert_status.miq_alert.link_text,
          "node_hostname" => alert_status.resource.name,
          "description"   => alert_status.miq_alert.description,
          "states"        => add_alert_status_state(alert_status)
        }
        result << alert
      end
      result
    end

    def add_alert_status_state(alert_status)
      results = []
      alert_status.miq_alert_status_states.includes(:user).each do |miq_alert_status_state|
        results << {
          :id                => miq_alert_status_state.id,
          :action            => miq_alert_status_state.action,
          :comment           => miq_alert_status_state.comment,
          :created_at        => miq_alert_status_state.created_at.to_time.to_i,
          :updated_at        => miq_alert_status_state.updated_at.to_time.to_i,
          :username          => miq_alert_status_state.user ? miq_alert_status_state.user.name : nil,
          :user_id           => miq_alert_status_state.user ? miq_alert_status_state.user.id : nil,
          :assignee_id       => miq_alert_status_state.assignee ? miq_alert_status_state.assignee.id : nil,
          :assignee_username => miq_alert_status_state.assignee ? miq_alert_status_state.assignee.name : nil
        }
      end
      results
    end
  end
end
