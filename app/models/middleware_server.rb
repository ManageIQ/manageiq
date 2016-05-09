class MiddlewareServer < ApplicationRecord
  include ReportableMixin

  belongs_to :ext_management_system, :foreign_key => "ems_id"
  has_many :middleware_deployments, :foreign_key => "server_id", :dependent => :destroy
  has_many :middleware_datasources, :foreign_key => "server_id", :dependent => :destroy
  serialize :properties
  acts_as_miq_taggable

  include LiveMetricsMixin

  # Used to describe Hawkular supported metrics for this resource and convert it into MiQ style names
  METRICS_HWK_MIQ = {
    "WildFly Memory Metrics~Heap Used"                                  => "mw_heap_used",
    "WildFly Aggregated Web Metrics~Aggregated Servlet Request Time"    => "mw_agregated_servlet_time",
    "WildFly Memory Metrics~NonHeap Committed"                          => "mw_non_heap_committed",
    "WildFly Aggregated Web Metrics~Aggregated Expired Web Sessions"    => "mw_aggregated_expired_web_sessions",
    "WildFly Aggregated Web Metrics~Aggregated Max Active Web Sessions" => "mw_aggregated_max_active_web_sessions",
    "WildFly Memory Metrics~Accumulated GC Duration"                    => "mw_accumulated_gc_duration",
    "WildFly Memory Metrics~Heap Max"                                   => "mw_heap_max",
    "WildFly Memory Metrics~Heap Committed"                             => "mw_heap_committed",
    "WildFly Memory Metrics~NonHeap Used"                               => "mw_non_heap_used",
    "WildFly Aggregated Web Metrics~Aggregated Servlet Request Count"   => "mw_aggregated_servlet_request_count",
    "WildFly Aggregated Web Metrics~Aggregated Active Web Sessions"     => "mw_aggregated_active_web_sessions",
    "WildFly Aggregated Web Metrics~Aggregated Rejected Web Sessions"   => "mw_aggregated_rejected_web_sessions",
    "WildFly Threading Metrics~Thread Count"                            => "mw_thread_count",
    "Server Availability~App Server"                                    => "mw_availability_app_server"
  }.freeze

  def metrics_capture
    @metrics_capture ||= ManageIQ::Providers::Hawkular::MiddlewareManager::LiveMetricsCapture.new(self)
  end

  delegate :metrics_available, :to => :metrics_capture
  delegate :collect_live_metric, :to => :metrics_capture
end
