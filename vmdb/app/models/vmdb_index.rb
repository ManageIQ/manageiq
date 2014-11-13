class VmdbIndex < ActiveRecord::Base
  belongs_to :vmdb_table

  has_many :vmdb_metrics,          :as => :resource  # Destroy will be handled by purger
  has_one  :latest_hourly_metric,  :as => :resource, :class_name => 'VmdbMetric', :conditions => {:capture_interval_name => 'hourly'}, :order => "timestamp DESC"

  include ReportableMixin
  include VmdbDatabaseMetricsMixin

  include_concern 'Seeding'
  include_concern 'VmdbIndex::MetricCapture'

  serialize :prior_raw_metrics

  def my_metrics
    self.vmdb_metrics
  end
end
