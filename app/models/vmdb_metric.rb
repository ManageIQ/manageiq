class VmdbMetric < ActiveRecord::Base
  belongs_to :resource, :polymorphic => true

  include_concern 'Purging'
  include ReportableMixin

  def self.rollup_metrics(resource, interval_name, rollup_date)

    # tp = TimeProfile.find_by_description("UTC")

    rows          = 0
    size          = 0
    wasted_bytes  = 0
    percent_bloat = 0

    # Check if a record already exists...
    metric   = resource.vmdb_metrics.where(:capture_interval_name  => 'daily', :timestamp => rollup_date.beginning_of_day).first
    metric ||= resource.vmdb_metrics.build(:capture_interval_name  => 'daily', :timestamp => rollup_date.beginning_of_day)

    # Fetch all hourly records for the table for date requested...
    # Metric::Finders.find_all_by_day(table, rollup_date, interval_name, tp).each do |h|
    resource.vmdb_metrics.where(:capture_interval_name => 'hourly', :timestamp => (rollup_date.beginning_of_day..rollup_date.end_of_day)).each do |h|
      # Data conversion added, found cases where nil values were stored in db...
      rows          += h.rows.to_i
      size          += h.size.to_i
      wasted_bytes  += h.wasted_bytes.to_i
      percent_bloat += h.percent_bloat.to_f
    end

    # Calculate averages for the day...
    rows          = rows / 24.0
    size          = size / 24.0
    wasted_bytes  = wasted_bytes / 24.0
    percent_bloat = percent_bloat / 24.0

    # Create new daily record...
    metric.update_attributes(:rows => rows, :size => size, :wasted_bytes => wasted_bytes, :percent_bloat => percent_bloat)

  end

end
