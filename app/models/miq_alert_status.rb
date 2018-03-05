class MiqAlertStatus < ApplicationRecord
  SEVERITY_LEVELS = %w(error warning info).freeze

  belongs_to :miq_alert
  belongs_to :resource, :polymorphic => true
  belongs_to :ext_management_system, :foreign_key => 'ems_id', :inverse_of => :miq_alert_statuses
  belongs_to :assignee, :class_name => 'User'
  has_many :miq_alert_status_actions, -> { order("created_at") }, :dependent => :destroy
  virtual_column :assignee, :type => :string
  virtual_column :hidden, :type => :boolean
  virtual_column :labels, :type => :string # This is actually an array of `MiqAlertStatusLabel` objects.

  validates :severity, :acceptance => { :accept => SEVERITY_LEVELS }

  def assigned?
    assignee_id.present?
  end

  def hidden?
    miq_alert_status_actions.where(:action_type => %w(hide show)).last.try(:action_type) == 'hide'
  end

  #
  # Returns the labels associated to this alert status.
  #
  # @return [Array<MiqAlertStatusLabel>] The array of labels.
  #
  def labels
    @labels ||= fetch_labels
  end

  private

  def fetch_labels
    ems = ext_management_system
    return [] unless ems&.supports_alert_labels?
    ems.alert_labels(self)
  end
end
