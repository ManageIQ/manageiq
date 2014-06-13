# Required for loading serialized objects in 'metric_obj' column
add_to_load_path Rails.root.join("..", "lib", "wbem")
require 'wbem'
require 'NetappManageabilityAPI/NmaTypes'

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
