module VmdbTableEvm::MetricCollection
  extend ActiveSupport::Concern

  module ClassMethods
    def collect_bloat(name)
      result   = connection.table_metrics_bloat(name).first if connection.respond_to?(:table_metrics_bloat)
      result ||= {
                   :rows          => 0,
                   :pages         => 0,
                   :percent_bloat => 0.0,
                   :wasted_bytes  => 0,
                   :otta          => 0,
                 }
      result.symbolize_keys
    end

    def collect_stats(name)
      result   = connection.table_metrics_analysis(name).first if connection.respond_to?(:table_metrics_analysis)
      result ||= {
                   :table_scans           => 0,
                   :sequential_rows_read  => 0,
                   :index_scans           => 0,
                   :index_rows_fetched    => 0,
                   :rows_inserted         => 0,
                   :rows_updated          => 0,
                   :rows_deleted          => 0,
                   :rows_hot_updated      => 0,
                   :rows_live             => 0,
                   :rows_dead             => 0,
                 }
      result.symbolize_keys
    end

    def collect_size(name)
      result = { :size => 0 }
      result[:size] = connection.table_metrics_total_size(name) if connection.respond_to?(:table_metrics_total_size)
      result
    end
  end
end
