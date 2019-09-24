module Metric::ConfigSettings
  def self.host_overhead
    ::Settings.performance.host_overhead
  end

  def self.host_overhead_memory
    # NOTE: VMware specific
    ::Settings.performance.host_overhead.memory.to_f_with_method
  end

  def self.host_overhead_cpu
    # NOTE: VMware specific
    ::Settings.performance.host_overhead.cpu.to_f_with_method
  end
end
