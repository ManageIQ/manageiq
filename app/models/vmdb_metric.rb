class VmdbMetric < ApplicationRecord
  belongs_to :resource, :polymorphic => true

  include_concern 'Purging'

  def self.rollup_metrics(resource, _interval_name, rollup_date)
    rows          = 0
    size          = 0
    wasted_bytes  = 0
    percent_bloat = 0

    # Check if a record already exists...
    metric   = resource.vmdb_metrics.find_by(:capture_interval_name  => 'daily', :timestamp => rollup_date.beginning_of_day)
    metric ||= resource.vmdb_metrics.build(:capture_interval_name  => 'daily', :timestamp => rollup_date.beginning_of_day)

    # Fetch all hourly records for the table for date requested...
    resource.vmdb_metrics.where(:capture_interval_name => 'hourly', :timestamp => (rollup_date.beginning_of_day..rollup_date.end_of_day)).each do |h|
      # Data conversion added, found cases where nil values were stored in db...
      rows += h.rows.to_i
      size += h.size.to_i
      wasted_bytes += h.wasted_bytes.to_i
      percent_bloat += h.percent_bloat.to_f
    end

    # Calculate averages for the day...
    rows /= 24.0
    size /= 24.0
    wasted_bytes /= 24.0
    percent_bloat /= 24.0

    # Create new daily record...
    metric.update(:rows => rows, :size => size, :wasted_bytes => wasted_bytes, :percent_bloat => percent_bloat)
  end

  def self.display_name(number = 1)
    n_('Metric', 'Metrics', number)
  end
end
