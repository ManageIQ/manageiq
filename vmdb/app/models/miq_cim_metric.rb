# Required for loading serialized objects in 'obj' column
require 'wbem'
require 'net_app_manageability/types'

class MiqCimMetric < MiqStorageMetric
  has_many  :miq_derived_metrics,
        :class_name   => "MiqCimDerivedMetric",
        :foreign_key  => "miq_storage_metric_id",
        :order      => :position,
        :dependent    => :destroy

  def rollup(curMetric, counterInfo)
    derivedMetrics = MiqCimDerivedMetric.new

    addDerivedMetric(derivedMetrics)
  end
end
