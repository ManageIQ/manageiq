class OntapDiskDerivedMetric < ActiveRecord::Base
  include ReportableMixin

  belongs_to    :miq_cim_instance
  belongs_to    :miq_storage_metric
  belongs_to    :storage_metrics_metadata
  serialize   :base_counters

  def self.additional_counters
    ["base_for_disk_busy"]
  end

  include OntapDerivedMetricMixin

  def self.derive_metrics(prevMetric, curMetric, counterInfo)
    derive_metrics_common(prevMetric, curMetric, counterInfo, "disk")
  end
end
