module AggregationMixin
  extend ActiveSupport::Concern
  included do
    virtual_sum :aggregate_cpu_speed,       :host_hardwares, :aggregate_cpu_speed
    virtual_sum :aggregate_cpu_total_cores, :host_hardwares, :cpu_total_cores
    virtual_sum :aggregate_disk_capacity,   :host_hardwares, :disk_capacity
    virtual_sum :aggregate_memory,          :host_hardwares, :memory_mb
    virtual_sum :aggregate_physical_cpus,   :host_hardwares, :cpu_sockets
    virtual_sum :aggregate_vm_cpus,         :vm_hardwares,   :cpu_sockets
    virtual_sum :aggregate_vm_memory,       :vm_hardwares,   :memory_mb
  end
end
