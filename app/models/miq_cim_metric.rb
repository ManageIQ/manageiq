# Required for loading serialized objects in 'obj' column
require 'wbem'
require 'net_app_manageability/types'

class MiqCimMetric < MiqStorageMetric
  has_many  :miq_derived_metrics, -> { order :position },
            :class_name  => "MiqCimDerivedMetric",
            :foreign_key => "miq_storage_metric_id",
            :dependent   => :destroy

  def rollup(_curMetric, _counterInfo)
    derivedMetrics = MiqCimDerivedMetric.new

    addDerivedMetric(derivedMetrics)
  end
end
