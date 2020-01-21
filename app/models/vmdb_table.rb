class VmdbTable < ApplicationRecord
  belongs_to :vmdb_database

  has_many :vmdb_indexes                             # Destroy will be handled by seeder
  has_many :vmdb_metrics,          :as => :resource  # Destroy will be handled by purger

  has_one  :latest_hourly_metric,  -> { VmdbMetric.where(:capture_interval_name => 'hourly', :resource_type => 'VmdbTable', :timestamp => VmdbMetric.maximum(:timestamp)) }, :as => :resource, :class_name => 'VmdbMetric'

  include VmdbDatabaseMetricsMixin

  serialize :prior_raw_metrics

  def my_metrics
    vmdb_metrics
  end

  def self.display_name(number = 1)
    n_('Table', 'Tables', number)
  end
end
