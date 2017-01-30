module Metric::CiMixin::LongTermAverages
  Metric::LongTermAverages::AVG_METHODS_INFO.each do |meth, info|
    define_method(meth) { averages_over_time_period(info[:column], info[:type]) }
  end

  Metric::LongTermAverages::AVG_METHODS_WITHOUT_OVERHEAD_INFO.each do |meth, info|
    define_method(meth) do
      base = send(info[:base_meth])
      base.nil? || self.kind_of?(Vm) ? base : [base - Metric::ConfigSettings.send("host_overhead_#{info[:overhead_type]}"), 0.0].max
    end
  end

  def generate_vim_performance_operating_ranges
    # TODO: Support generation for all known TimeProfiles
    generate_vim_performance_operating_range(TimeProfile.default_time_profile)
  end

  private

  def generate_vim_performance_operating_range(time_profile)
    vpor = vim_performance_operating_ranges
           .create_with(:days => Metric::LongTermAverages::AVG_DAYS)
           .find_or_create_by(:time_profile => time_profile)
    vpor.recalculate_values
    vpor.save!
  end

  def averages_over_time_period(col, typ)
    # TODO: Deal with choosing the right TimeProfile.  See #generate_vim_performance_operating_ranges
    #   For now just use the one vpor which is tied to the default TimeProfile.
    vpor = vim_performance_operating_ranges.first
    vpor.nil? ? 0 : vpor.values_to_metrics["#{col}_#{typ}_over_time_period"]
  end
end
