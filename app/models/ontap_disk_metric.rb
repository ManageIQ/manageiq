class OntapDiskMetric < MiqStorageMetric
  DERIVED_METRICS_CLASS_NAME  = "OntapDiskDerivedMetric"
  METRICS_ROLLUP_CLASS_NAME = "OntapDiskMetricsRollup"

  has_many  :miq_derived_metrics,
        :class_name   => DERIVED_METRICS_CLASS_NAME,
        :foreign_key  => "miq_storage_metric_id",
        :dependent    => :destroy

  has_many  :miq_metrics_rollups,
        :class_name   => METRICS_ROLLUP_CLASS_NAME,
        :foreign_key  => "miq_storage_metric_id",
        :dependent    => :destroy
end
