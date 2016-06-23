class MiddlewareServer < ApplicationRecord
  belongs_to :ext_management_system, :foreign_key => "ems_id"
  belongs_to :lives_on, :polymorphic => true
  has_many :middleware_deployments, :foreign_key => "server_id", :dependent => :destroy
  has_many :middleware_datasources, :foreign_key => "server_id", :dependent => :destroy
  serialize :properties
  acts_as_miq_taggable

  include LiveMetricsMixin

  def metrics_capture
    @metrics_capture ||= ManageIQ::Providers::Hawkular::MiddlewareManager::LiveMetricsCapture.new(self)
  end
end
