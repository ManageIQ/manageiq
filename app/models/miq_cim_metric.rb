# Required for loading serialized objects in 'obj' column
require 'wbem'
require 'net_app_manageability/types'

class MiqCimMetric < MiqStorageMetric
  DERIVED_METRICS_CLASS_NAME = "MiqCimDerivedMetric"

  has_many  :miq_derived_metrics, -> { order :position },
            :class_name  => DERIVED_METRICS_CLASS_NAME,
            :foreign_key => "miq_storage_metric_id",
            :dependent   => :destroy

  def rollup(_curMetric, _counterInfo)
    derivedMetrics = MiqCimDerivedMetric.new

    addDerivedMetric(derivedMetrics)
  end
end
