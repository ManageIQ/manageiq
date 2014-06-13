class OntapAggregateMetricsRollup < ActiveRecord::Base
  include ReportableMixin

  belongs_to    :miq_cim_instance
  belongs_to    :miq_storage_metric
  belongs_to    :storage_metrics_metadata
  serialize   :base_counters
  belongs_to    :time_profile

  def self.additional_counters
    []
  end

  include OntapMetricsRollupMixin
end
