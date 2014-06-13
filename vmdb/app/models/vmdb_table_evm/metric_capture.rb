module VmdbTableEvm::MetricCapture
  extend ActiveSupport::Concern

  include_concern 'VmdbTableEvm::MetricCollection'

  def capture_metrics(timestamp = Time.now)

    # Modify the list as needed, for now it keeps track of data that changes since db startup or vaccuum
    exclude_from_prior = %w{
      size
      rows
      pages
      otta
      percent_bloat
      wasted_bytes
      timestamp
      last_vacuum_date
      last_autovacuum_date
      last_analyze_date
      last_autoanalyze_date
      capture_interval_name
    }

    attrs = {
      :timestamp             => ::Metric::Helper.nearest_hourly_timestamp(timestamp),
      :capture_interval_name => 'hourly'
    }

    attrs.merge!(self.class.collect_bloat(self.name))
    attrs.merge!(self.class.collect_stats(self.name))
    attrs.merge!(self.class.collect_size(self.name))

    attrs = attrs.delete_if { |key, value| !VmdbMetric.column_names.include?(key.to_s) }

    unless self.prior_raw_metrics.nil?
      delta_attrs = {}
      self.prior_raw_metrics.keys.each do |k|
        next if attrs[k].nil? || self.prior_raw_metrics[k].nil?
        delta_attrs[k] = attrs[k] - self.prior_raw_metrics[k]
      end

      # Make sure to include these columns in the metrics themselves...
      exclude_from_prior.each { |k| delta_attrs[k.to_sym] = attrs[k.to_sym] }

      self.vmdb_metrics.create(delta_attrs)
    end

    # Exlude these columns from delta calculations...
    exclude_from_prior.each { |k| attrs.delete(k.to_sym) }

    self.update_attributes(:prior_raw_metrics => attrs)

    capture_index_metrics(timestamp)
  end

  def capture_index_metrics(timestamp = Time.now)
    vmdb_indexes.each { |index| index.capture_metrics(timestamp) }
  end

  def rollup_metrics(interval_name, rollup_date)
    VmdbMetric.rollup_metrics(self, interval_name, rollup_date)

    vmdb_indexes.each { |index| index.rollup_metrics(interval_name, rollup_date) }
  end

end
