require 'ancestry'

class MiqAlertStatus < ApplicationRecord
  SEVERITY_LEVELS = %w(error warning info).freeze

  has_ancestry
  belongs_to :miq_alert
  belongs_to :resource, :polymorphic => true
  has_many :miq_alert_status_actions, -> { order "created_at" }, :dependent => :destroy
  virtual_column :assignee, :type => :string

  validates :severity, :acceptance => { :accept => SEVERITY_LEVELS }

  def assignee
    miq_alert_status_actions.where(:action_type => %w(assign unassign)).last.try(:assignee)
  end

  def assigned?
    assignee.present?
  end
end
