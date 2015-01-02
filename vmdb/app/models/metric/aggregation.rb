module Metric::Aggregation
  module Aggregate
    def self.average(col, obj, result, counts, value)
      return if value.nil?
      result[col] += value
      counts[col] += 1
    end

    def self.summation(col, obj, result, counts, value)
      return if value.nil?
      result[col] += value
      counts[col] += 1
    end

    class << self
      alias derived_vm_numvcpus summation
    end

    def self.latest(col, obj, result, counts, value)
      return if value.nil?
      result[col] = value
    end

    def self.cpu_usage_rate_average(col, state, result, counts, value)
      return if value.nil?
      if state && state.total_cpu
        pct = ( value / 100 )
        total = state.total_cpu
        value = ( total * pct )
        result[col] += value
      else
        self.average(col, state, result, counts, value)
      end
    end

    def self.mem_usage_absolute_average(col, state, result, counts, value)
      return if value.nil?
      if state && state.total_mem
        pct = ( value / 100 )
        total = state.total_mem
        value = ( total * pct )
        result[col] += value
      else
        self.average(col, state, result, counts, value)
      end
    end
  end

  module Process
    def self.average(col, dummy, result, counts, aggregate_only = false)
      return if aggregate_only || result[col].nil?
      result[col] = ( result[col] / counts[col] ) unless counts[col] == 0
    end

    def self.summation(*args)
      # noop
    end

    class << self
      alias derived_vm_numvcpus   summation
    end

    def self.latest(*args)
      # noop
    end

    def self.cpu_usage_rate_average(col, state, result, counts, aggregate_only = false)
      return if result[col].nil?
      if state && state.total_cpu
        total = state.total_cpu
        result[col] = ( result[col] / total * 100 ) unless total == 0
      else
        self.average(col, state, result, counts) unless aggregate_only
      end
    end

    def self.mem_usage_absolute_average(col, state, result, counts, aggregate_only = false)
      return if result[col].nil?
      if state && state.total_mem
        total = state.total_mem
        result[col] = ( result[col] / total * 100 ) unless total == 0
      else
        self.average(col, state, result, counts) unless aggregate_only
      end
    end
  end

  def self.aggregate_for_column(*args)
    self.execute_for_column(Aggregate, *args)
  end

  def self.process_for_column(*args)
    self.execute_for_column(Process, *args)
  end

  def self.execute_for_column(mode, col, *args) # args => obj, result, counts, value, default_operation = nil
    default_operation = args[4]
    args = args[0..3]

    meth = col
    meth = col.to_s.split("_").last unless supports?(mode, meth)
    meth = default_operation        unless supports?(mode, meth) || default_operation.nil?
    mode.send(meth, col, *args) if supports?(mode, meth)
  end

  def self.supports?(mode, meth)
    mode.singleton_methods(false).include?(meth.to_sym)
  end
end
