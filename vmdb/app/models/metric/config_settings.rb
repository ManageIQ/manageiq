module Metric::ConfigSettings
  def self.host_overhead
    VMDB::Config.new("vmdb").config.fetch_path(:performance, :host_overhead) || {}
  end

  def self.host_overhead_memory
    # NOTE: VMware specific
    (host_overhead[:memory] || 2.01).to_f_with_method
  end

  def self.host_overhead_cpu
    # NOTE: VMware specific
    (host_overhead[:cpu] || 0.15).to_f_with_method
  end
end
