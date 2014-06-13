class MetricRollup < ActiveRecord::Base
  include Metric::Common

  def self.find_all_by_interval_and_time_range(interval, start_time, end_time = nil, count = :all, options = {})
    my_cond = ["capture_interval_name = ? and timestamp > ? and timestamp <= ?", interval, start_time, end_time]

    passed_cond = options.delete(:conditions)
    options[:conditions] = passed_cond.nil? ? my_cond : "( #{self.send(:sanitize_sql_for_conditions, my_cond)} ) AND ( #{self.send(:sanitize_sql, passed_cond)} )"

    $log.debug("#{self.name}.find_all_by_interval_and_time_range: Find options: #{options.inspect}")
    self.find(count, options)
  end

  #
  # min_max column getters
  #

  Metric::Rollup::ROLLUP_COLS.product([:min, :max]).each do |c, mode|
    col = "#{mode}_#{c}".to_sym
    define_method(col) { extract_from_min_max(col) }
    virtual_column col, :type => :float
  end

  Metric::Rollup::BURST_COLS.product([:min, :max]).each do |c, mode|
    col = "abs_#{mode}_#{c}_value".to_sym
    define_method(col) { extract_from_min_max(col) }
    virtual_column col, :type => :float
  end

  Metric::Rollup::BURST_COLS.product([:min, :max]).each do |c, mode|
    col = "abs_#{mode}_#{c}_timestamp".to_sym
    define_method(col) { extract_from_min_max(col) }
    virtual_column col, :type => :datetime
  end

  def extract_from_min_max(col)
    self.min_max ||= {}
    val = self.min_max[col.to_sym]

    # HACK: for non-vmware environments, *_reserved values are 0.
    # Assume, a nil or 0 reservation means all available memory/cpu is available by using the *_available column.
    # This should really be done by subclassing where each subclass can define reservations or
    # changing the reports to allow for optional reservations.
    if val.to_i == 0 && col.to_s =~ /(.+)_reserved$/
      return self.send("#{$1}_available")
    else
      return val
    end
  end
end
