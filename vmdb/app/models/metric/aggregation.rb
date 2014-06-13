module Metric::Aggregation
  def self.aggregate_for_column(*args)
    self.execute_for_column(:aggregate, *args)
  end

  def self.process_for_column(*args)
    self.execute_for_column(:process, *args)
  end

  def self.execute_for_column(mode, col, *args) # args => obj, result, counts, value, default_operation = nil
    default_operation = args[4]
    args = args[0..3]

    meth = "#{mode}_#{col}"
    meth = "#{mode}_#{col.to_s.split("_").last}" unless self.respond_to?(meth)
    meth = "#{mode}_#{default_operation}"        unless self.respond_to?(meth) || default_operation.nil?
    self.send(meth, col, *args) if self.respond_to?(meth)
  end

  def self.aggregate_average(col, obj, result, counts, value)
    return if value.nil?
    result[col] += value
    counts[col] += 1
  end

  def self.process_average(col, dummy, result, counts, aggregate_only = false)
    return if aggregate_only || result[col].nil?
    result[col] = ( result[col] / counts[col] ) unless counts[col] == 0
  end

  def self.aggregate_summation(col, obj, result, counts, value)
    return if value.nil?
    result[col] += value
    counts[col] += 1
  end

  def self.process_summation(*args)
    # noop
  end

  class << self
    alias aggregate_derived_vm_numvcpus aggregate_summation
    alias process_derived_vm_numvcpus   process_summation
  end

  def self.aggregate_latest(col, obj, result, counts, value)
    return if value.nil?
    result[col] = value
  end

  def self.process_latest(*args)
    # noop
  end

  def self.aggregate_cpu_usage_rate_average(col, state, result, counts, value)
    return if value.nil?
    if state && state.total_cpu
      pct = ( value / 100 )
      total = state.total_cpu
      value = ( total * pct )
      result[col] += value
    else
      self.aggregate_average(col, state, result, counts, value)
    end
  end

  def self.process_cpu_usage_rate_average(col, state, result, counts, aggregate_only = false)
    return if result[col].nil?
    if state && state.total_cpu
      total = state.total_cpu
      result[col] = ( result[col] / total * 100 ) unless total == 0
    else
      self.process_average(col, state, result, counts) unless aggregate_only
    end
  end

  def self.aggregate_mem_usage_absolute_average(col, state, result, counts, value)
    return if value.nil?
    if state && state.total_mem
      pct = ( value / 100 )
      total = state.total_mem
      value = ( total * pct )
      result[col] += value
    else
      self.aggregate_average(col, state, result, counts, value)
    end
  end

  def self.process_mem_usage_absolute_average(col, state, result, counts, aggregate_only = false)
    return if result[col].nil?
    if state && state.total_mem
      total = state.total_mem
      result[col] = ( result[col] / total * 100 ) unless total == 0
    else
      self.process_average(col, state, result, counts) unless aggregate_only
    end
  end
end
