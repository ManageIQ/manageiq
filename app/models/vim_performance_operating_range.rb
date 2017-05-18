class VimPerformanceOperatingRange < ApplicationRecord
  belongs_to  :resource, :polymorphic => true
  belongs_to  :time_profile

  serialize   :values

  DEFAULT_STD_DEV_MULT = 1

  def recalculate_values
    self.values = Metric::LongTermAverages.get_averages_over_time_period(
      resource,
      :avg_days    => days,
      :ext_options => {:time_profile => time_profile}
    )
  end

  def values_to_metrics(options = {})
    @values_with_metrics ||= begin
      results = values_with_std_dev(options[:std_dev_mult])
      Metric::LongTermAverages::AVG_METHODS_INFO.each_with_object({}) do |(meth, info), h|
        h[meth.to_s] = results.fetch_path(info[:type], info[:column])
      end
    end
  end

  private

  def values_with_std_dev(std_dev_mult)
    std_dev_mult ||= DEFAULT_STD_DEV_MULT

    results = values.dup.merge(:low => {}, :high => {})
    results[:avg].each_key do |c|
      dev = (results[:dev][c] * std_dev_mult)
      results[:low][c]  = results[:avg][c] - dev
      results[:low][c]  = 0 if results[:low][c] < 0
      results[:high][c] = results[:avg][c] + dev
    end
    results
  end
end
