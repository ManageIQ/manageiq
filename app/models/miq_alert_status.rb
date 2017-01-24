require 'ancestry'

class MiqAlertStatus < ApplicationRecord
  SEVERITY_LEVELS = %w(error warning info).freeze

  has_ancestry
  belongs_to :miq_alert
  belongs_to :resource, :polymorphic => true
  belongs_to :ext_management_system
  has_many :miq_alert_status_actions, -> { order "created_at" }, :dependent => :destroy
  virtual_column :assignee, :type => :string
  virtual_column :hidden, :type => :boolean

  validates :severity, :acceptance => { :accept => SEVERITY_LEVELS }

  def assignee
    miq_alert_status_actions.where(:action_type => %w(assign unassign)).last.try(:assignee)
  end

  def assigned?
    assignee.present?
  end

  def hidden?
    miq_alert_status_actions.where(:action_type => %w(hide show)).last.try(:action_type) == 'hide'
  end
end
