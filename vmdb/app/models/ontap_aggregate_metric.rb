class OntapAggregateMetric < MiqStorageMetric
  DERIVED_METRICS_CLASS_NAME  = "OntapAggregateDerivedMetric"
  METRICS_ROLLUP_CLASS_NAME = "OntapAggregateMetricsRollup"

  has_many  :miq_derived_metrics,
        :class_name   => DERIVED_METRICS_CLASS_NAME,
        :foreign_key  => "miq_storage_metric_id",
        :dependent    => :destroy

  has_many  :miq_metrics_rollups,
        :class_name   => METRICS_ROLLUP_CLASS_NAME,
        :foreign_key  => "miq_storage_metric_id",
        :dependent    => :destroy
end
