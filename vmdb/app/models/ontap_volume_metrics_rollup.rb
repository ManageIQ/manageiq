class OntapVolumeMetricsRollup < ActiveRecord::Base
  include ReportableMixin

  belongs_to    :miq_cim_instance
  belongs_to    :miq_storage_metric
  belongs_to    :storage_metrics_metadata
  belongs_to    :time_profile
  serialize   :base_counters

  virtual_column :v_statistic_date,   :type => :datetime
  virtual_column :v_statistic_time,   :type => :datetime
  virtual_column :resource_name,      :type => :string, :uses => :miq_cim_instance

  def resource_name
    self.miq_cim_instance.name
  end

  def self.additional_counters
    []
  end

  include OntapMetricsRollupMixin
end
