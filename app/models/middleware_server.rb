class MiddlewareServer < ApplicationRecord
  belongs_to :ext_management_system, :foreign_key => "ems_id"
  belongs_to :middleware_server_group, :foreign_key => "server_group_id"
  belongs_to :lives_on, :polymorphic => true
  has_many :middleware_deployments, :foreign_key => "server_id", :dependent => :destroy
  has_many :middleware_datasources, :foreign_key => "server_id", :dependent => :destroy
  has_many :middleware_messagings, :foreign_key => "server_id", :dependent => :destroy
  serialize :properties
  acts_as_miq_taggable

  include LiveMetricsMixin

  def metrics_capture
    @metrics_capture ||= ManageIQ::Providers::Hawkular::MiddlewareManager::LiveMetricsCapture.new(self)
  end

  def tenant_identity
    if ext_management_system
      ext_management_system.tenant_identity
    else
      User.super_admin.tap { |u| u.current_group = Tenant.root_tenant.default_miq_group }
    end
  end

  def evaluate_alert(alert_id, event)
    s_start = event.full_data.index("id=\"") + 4
    s_end = event.full_data.index("\"", s_start + 4) - 1
    event_id = event.full_data[s_start..s_end]
    if event_id.start_with?("MiQ-#{alert_id}") && event.middleware_server_id == id
      return true
    end
    false
  end

  def in_domain?
    !middleware_server_group.nil?
  end
end
