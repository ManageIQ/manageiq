module VmdbIndex::MetricCollection
  extend ActiveSupport::Concern

  module ClassMethods
    def collect_bloat(name)
     result   = connection.index_metrics_bloat(name).first if connection.respond_to?(:index_metrics_bloat)
      result ||= {
                   :rows          => 0,
                   :pages         => 0,
                   :otta          => 0,
                   :percent_bloat => 0.0,
                   :wasted_bytes  => 0
                 }
      result.symbolize_keys
    end

    def collect_stats(name)
      result   = connection.index_metrics_analysis(name).first if connection.respond_to?(:index_metrics_analysis)
      result ||= {
                   :table_id              => 0,
                   :index_id              => 0,
                   :index_scans           => 0,
                   :index_rows_read       => 0,
                   :index_rows_fetched    => 0
                 }
      result.symbolize_keys
    end

  end
end
