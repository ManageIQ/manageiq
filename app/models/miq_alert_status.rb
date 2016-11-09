class MiqAlertStatus < ApplicationRecord
  belongs_to :miq_alert
  belongs_to :resource, :polymorphic => true
  belongs_to :user

  SEVERITY_LEVELS = %w(danger warning info).freeze
end
