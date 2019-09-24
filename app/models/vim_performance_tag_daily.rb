class VimPerformanceTagDaily < VimPerformanceTag
  def self.instances_are_derived?
    true
  end

  # @options ext_options :time_profile
  # @options ext_options :tz
  # @options ext_options :class
  def self.find_entries(ext_options)
    ext_options ||= {}
    Metric::Helper.find_for_interval_name("daily", ext_options[:time_profile] || ext_options[:tz], ext_options[:class])
  end
end
