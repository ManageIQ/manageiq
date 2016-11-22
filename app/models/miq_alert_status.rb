class MiqAlertStatus < ApplicationRecord
  belongs_to :miq_alert
  belongs_to :resource, :polymorphic => true
  has_many :miq_alert_status_states
  SEVERITY_LEVELS = %w(danger warning info).freeze

  def alert_status_and_states
    {
      "id"            => id,
      "evaluated_on"  => evaluated_on,
      "link_text"     => miq_alert.link_text,
      "node_hostname" => resource.name,
      "description"   => miq_alert.description,
      "severity"      => miq_alert.severity,
      "states"        => alert_states_history
    }
  end

  def alert_states_history
    results = []
    miq_alert_status_states.includes(:user, :assignee).each do |miq_alert_status_state|
      results << {
        :id                => miq_alert_status_state.id,
        :action            => miq_alert_status_state.action,
        :comment           => miq_alert_status_state.comment,
        :created_at        => miq_alert_status_state.created_at,
        :updated_at        => miq_alert_status_state.updated_at,
        :username          => miq_alert_status_state.user ? miq_alert_status_state.user.name : nil,
        :user_id           => miq_alert_status_state.user ? miq_alert_status_state.user.id : nil,
        :assignee_id       => miq_alert_status_state.assignee ? miq_alert_status_state.assignee.id : nil,
        :assignee_username => miq_alert_status_state.assignee ? miq_alert_status_state.assignee.name : nil
      }
    end
    results
  end
end
