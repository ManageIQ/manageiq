class MiqAlertStatus < ApplicationRecord
  belongs_to :miq_alert
  belongs_to :resource, :polymorphic => true
  belongs_to :miq_user
end
