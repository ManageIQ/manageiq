class MiqAlertStatusState < ApplicationRecord
  belongs_to :miq_alert_status
  belongs_to :user
  belongs_to :assignee, :class_name => 'User'
  ACTION_TYPES = %w(assign acknowledge comment unassign unacknowledge).freeze
  validates :action, :acceptance => { :accept => ACTION_TYPES }, :presence => true
end
