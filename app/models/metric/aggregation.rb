module Metric::Aggregation
  class Common
    def self.supports?(meth)
      singleton_methods(false).include?(meth.to_sym)
    end

    def self.column(col, *args) # args => obj, result, counts, value, default_operation = nil
      default_operation = args[4]
      args = args[0..3]

      meth = col
      meth = col.to_s.split("_").last unless supports?(meth)
      meth = default_operation        unless supports?(meth) || default_operation.nil?
      send(meth, col, *args) if supports?(meth)
    end
  end

  class Aggregate < Common
    def self.summation(col, _obj, result, counts, value)
      return if value.nil?
      result[col] += value
      counts[col] += 1
    end

    class << self
      alias_method :derived_vm_numvcpus, :summation
      alias_method :average, :summation
    end

    def self.latest(col, _obj, result, _counts, value)
      return if value.nil?
      result[col] = value
    end

    def self.cpu_usage_rate_average(col, state, result, counts, value)
      return if value.nil?
      if state.try(:total_cpu).to_i > 0
        pct = value / 100
        total = state.total_cpu
        value = total * pct
        result[col] += value
      elsif state.try(:numvcpus).to_i > 0
        result[col] += value * state.numvcpus
        counts[col] += state.numvcpus
      else
        average(col, state, result, counts, value)
      end
    end

    def self.mem_usage_absolute_average(col, state, result, counts, value)
      return if value.nil?
      if state && state.total_mem
        pct = value / 100
        total = state.total_mem
        value = total * pct
        result[col] += value
      else
        average(col, state, result, counts, value)
      end
    end
  end

  class Process < Common
    def self.average(col, _dummy, result, counts, aggregate_only = false)
      return if aggregate_only || result[col].nil?
      result[col] = result[col] / counts[col] unless counts[col] == 0
    end

    def self.summation(*)
      # noop
    end

    class << self
      alias_method :latest, :summation
    end

    def self.cpu_usage_rate_average(col, state, result, counts, aggregate_only = false)
      return if result[col].nil?
      if state.try(:total_cpu).to_i > 0
        total = state.total_cpu
        result[col] = result[col] / total * 100 unless total == 0
      else
        average(col, state, result, counts) unless aggregate_only
      end
    end

    def self.mem_usage_absolute_average(col, state, result, counts, aggregate_only = false)
      return if result[col].nil?
      if state && state.total_mem
        total = state.total_mem
        result[col] = result[col] / total * 100 unless total == 0
      else
        average(col, state, result, counts) unless aggregate_only
      end
    end
  end
end
