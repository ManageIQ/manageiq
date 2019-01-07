class VmdbIndex < ApplicationRecord
  belongs_to :vmdb_table

  has_many :vmdb_metrics,          :as => :resource  # Destroy will be handled by purger

  has_one  :latest_hourly_metric,  -> { VmdbMetric.where(:capture_interval_name => 'hourly', :resource_type => 'VmdbIndex', :timestamp => VmdbMetric.maximum(:timestamp)) }, :as => :resource, :class_name => 'VmdbMetric'

  include VmdbDatabaseMetricsMixin

  include_concern 'VmdbIndex::MetricCapture'

  serialize :prior_raw_metrics

  def my_metrics
    vmdb_metrics
  end

  def self.display_name(number = 1)
    n_('Index', 'Indexes', number)
  end
end
