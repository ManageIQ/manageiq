class VimPerformanceOperatingRange < ActiveRecord::Base
  belongs_to  :resource, :polymorphic => true
  belongs_to  :time_profile

  serialize   :values

  DEFAULT_STD_DEV_MULT = 1

  def values_to_metrics(options={})
    options[:std_dev_mult] ||= DEFAULT_STD_DEV_MULT

    results = self.values.dup.merge(:low=>{}, :high=>{})
    results[:avg].each_key do |c|
      dev = (results[:dev][c] * options[:std_dev_mult])
      results[:low][c]  = results[:avg][c] - dev
      results[:low][c]  = 0 if results[:low][c] < 0
      results[:high][c] = results[:avg][c] + dev
    end

    metrics = {}
    Metric::LongTermAverages::AVG_METHODS_INFO.each do |meth, info|
      metrics[meth.to_s] = results.fetch_path(info[:type], info[:column])
    end

    return metrics
  end
end
