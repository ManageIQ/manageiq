class MiqAlertStatus < ApplicationRecord
  include_concern 'Purging'

  belongs_to :miq_alert
  belongs_to :resource, :polymorphic => true
end
