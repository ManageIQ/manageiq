module ManageIQ::Providers
  class Kubernetes::ContainerManager::LongTermAverages
    AVG_COLS = %i(max_cpu_usage_rate_average
                  max_mem_usage_absolute_average).freeze
    AVG_DAYS = 30

    def self.get_averages_over_time_period(obj, options = {})
      results = {:avg => {}, :dev => {}}
      vals = {}
      counts = {}
      ext_options = options.delete(:ext_options) || {}
      tz = Metric::Helper.get_time_zone(ext_options)
      avg_days = options[:avg_days] || AVG_DAYS
      avg_cols = options[:avg_cols] || AVG_COLS

      ext_options = ext_options.merge(:only_cols => avg_cols)

      perfs = ManageIQ::Providers::Kubernetes::ContainerManager::VimPerformanceAnalysis.find_perf_for_time_period(
        obj,
        "daily",
        :end_date    => options[:end_date] || Time.now.utc,
        :days        => avg_days,
        :ext_options => ext_options
      )

      perfs.each do |p|
        if ext_options[:time_profile] && !ext_options[:time_profile].ts_day_in_profile?(p.timestamp.in_time_zone(tz))
          next
        end

        avg_cols.each do |c|
          vals[c] ||= []
          results[:avg][c] ||= 0
          counts[c] ||= 0

          val = p.send(c) || 0
          vals[c] << val
          val *= 1.0 unless val.nil?
          Metric::Aggregation::Aggregate.average(c, self, results[:avg], counts, val)
        end
      end

      results[:avg].each_key do |c|
        Metric::Aggregation::Process.average(c, nil, results[:avg], counts)

        begin
          results[:dev][c] = vals[c].length == 1 ? 0 : vals[c].stddev
          raise StandardError, "result was NaN" if results[:dev][c].try(:nan?)
        rescue => err
          _log.warn("Unable to calculate standard deviation, '#{err.message}', values: #{vals[c].inspect}")
          results[:dev][c] = 0
        end
      end

      results
    end
  end
end
