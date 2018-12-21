class MiqAlertStatus < ApplicationRecord
  SEVERITY_LEVELS = %w(error warning info).freeze

  belongs_to :miq_alert
  belongs_to :resource, :polymorphic => true
  belongs_to :ext_management_system
  belongs_to :assignee, :class_name => 'User'
  has_many :miq_alert_status_actions, -> { order("created_at") }, :dependent => :destroy
  virtual_column :assignee, :type => :string
  virtual_column :hidden, :type => :boolean

  validates :severity, :acceptance => { :accept => SEVERITY_LEVELS }

  def assigned?
    assignee_id.present?
  end

  def hidden?
    miq_alert_status_actions.where(:action_type => %w(hide show)).last.try(:action_type) == 'hide'
  end

  def self.display_name(number = 1)
    n_('Alert Status', 'Alert Statuses', number)
  end
end
