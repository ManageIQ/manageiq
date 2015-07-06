class OntapSystemMetricsRollup < ActiveRecord::Base
  include ReportableMixin

  belongs_to    :miq_cim_instance
  belongs_to    :miq_storage_metric
  belongs_to    :storage_metrics_metadata
  belongs_to    :time_profile
  serialize   :base_counters

  def self.additional_counters
    [ "cpu_elapsed_time", "cpu_elapsed_time1", "cpu_elapsed_time2" ]
  end

  include OntapMetricsRollupMixin
end
