module VmdbDatabase::MetricCapture
  extend ActiveSupport::Concern

  include_concern 'VmdbDatabase::MetricCollection'

  module ClassMethods
    def capture_metrics_timer(timestamp = Time.now)
      my_database.capture_metrics(timestamp)
    end

    def rollup_metrics_timer(timestamp = Time.now)
      my_database.rollup_metrics(timestamp)
    end
  end

  def capture_metrics(timestamp = Time.now)
    capture_database_metrics(timestamp)
    capture_table_metrics(timestamp)
  end

  def capture_database_metrics(timestamp = Time.now)
    return unless self.class.connection.adapter_name.downcase == "postgresql"
    attrs = {
      :timestamp             => ::Metric::Helper.nearest_hourly_timestamp(timestamp),
      :capture_interval_name => 'hourly'
    }

    attrs = attrs.merge(self.class.collect_database_metrics_sql)
    attrs = attrs.merge(self.class.collect_database_metrics_os(self.data_directory)) if EvmDatabase.local?

    self.vmdb_database_metrics.create(attrs)
  end

  def capture_table_metrics(timestamp = Time.now)
    vmdb_tables.each { |table| table.capture_metrics }
  end

  def rollup_metrics(timestamp = Time.now)
    self.evm_tables.each { |table| table.rollup_metrics('daily', timestamp.beginning_of_day) }
  end

end
