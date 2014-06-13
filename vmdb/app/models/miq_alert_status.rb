class MiqAlertStatus < ActiveRecord::Base
  belongs_to :miq_alert
  belongs_to :resource, :polymorphic => true
end
