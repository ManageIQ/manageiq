class MiddlewareDatasource < ApplicationRecord
  include NewWithTypeStiMixin
  include LiveMetricsMixin

  belongs_to :ext_management_system, :foreign_key => "ems_id"
  belongs_to :middleware_server, :foreign_key => "server_id"
  acts_as_miq_taggable
  serialize :properties

  delegate :mutable?, :in_domain?, :to => :middleware_server

  def metrics_capture
    @metrics_capture ||= ManageIQ::Providers::Hawkular::MiddlewareManager::LiveMetricsCapture.new(self)
  end
end
