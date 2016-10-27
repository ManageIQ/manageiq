class MiqAlertStatus < ApplicationRecord
  belongs_to :miq_alert
  belongs_to :resource, :polymorphic => true
  has_many :miq_alert_status_states
  SEVERITY_LEVELS = %w(danger warning info).freeze
end
