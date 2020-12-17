module AggregationMixin
  extend ActiveSupport::Concern
  included do
    virtual_aggregate :aggregate_cpu_speed,       :host_hardwares, :sum, :aggregate_cpu_speed
    virtual_aggregate :aggregate_cpu_total_cores, :host_hardwares, :sum, :cpu_total_cores
    virtual_aggregate :aggregate_disk_capacity,   :host_hardwares, :sum, :disk_capacity
    virtual_aggregate :aggregate_memory,          :host_hardwares, :sum, :memory_mb
    virtual_aggregate :aggregate_physical_cpus,   :host_hardwares, :sum, :cpu_sockets
    virtual_aggregate :aggregate_vm_cpus,         :vm_hardwares,   :sum, :cpu_sockets
    virtual_aggregate :aggregate_vm_memory,       :vm_hardwares,   :sum, :memory_mb

    alias_method :all_vms_and_templates,  :vms_and_templates
    alias_method :all_vm_or_template_ids, :vm_or_template_ids
  end
end
