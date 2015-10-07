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
    attrs = {
      :timestamp             => ::Metric::Helper.nearest_hourly_timestamp(timestamp),
      :capture_interval_name => 'hourly'
    }

    attrs = attrs.merge(self.class.collect_database_metrics_sql)
    attrs = attrs.merge(self.class.collect_database_metrics_os(data_directory)) if EvmDatabase.local?

    vmdb_database_metrics.create(attrs)
  end

  def capture_table_metrics(_timestamp = Time.now)
    vmdb_tables.each(&:capture_metrics)
  end

  def rollup_metrics(timestamp = Time.now)
    evm_tables.each { |table| table.rollup_metrics('daily', timestamp.beginning_of_day) }
  end
end
