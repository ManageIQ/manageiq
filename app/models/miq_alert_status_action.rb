class MiqAlertStatusAction < ApplicationRecord
  ACTION_TYPES = %w(assign acknowledge comment unassign unacknowledge).freeze

  belongs_to :miq_alert_status
  belongs_to :assignee, :class_name => 'User'
  belongs_to :user
  validates :action_type, :acceptance => { :accept => ACTION_TYPES }, :presence => true
  validates :user, :presence => true
  validates :miq_alert_status, :presence => true
  validates :comment, :presence => true, :if => "action_type == 'comment'"
  validates :assignee, :presence => true, :if => "action_type == 'assign'"
  validates :assignee, :absence => true, :unless => "action_type == 'assign'"
  validate :only_assignee_can_acknowledge

  after_save :update_status_acknowledgement

  def only_assignee_can_acknowledge
    if action_type == 'acknowledge' && miq_alert_status.assignee.try(:id) != user.id
      errors.add(:user, "that is not assigned cannot acknowledge")
    end
  end

  def update_status_acknowledgement
    if %w(assign unassign unacknowledge).include?(action_type)
      miq_alert_status.update(:acknowledged => false)
    elsif "acknowledge" == action_type
      miq_alert_status.update(:acknowledged => true)
    end
  end
end
