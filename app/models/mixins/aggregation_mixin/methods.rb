module AggregationMixin
  module Methods
    extend ActiveSupport::Concern

    def aggregate_cpu_speed(targets = nil)
      aggregate_hardware(:hosts, :aggregate_cpu_speed, targets)
    end

    def aggregate_cpu_total_cores(targets = nil)
      aggregate_hardware(:hosts, :cpu_total_cores, targets)
    end

    def aggregate_physical_cpus(targets = nil)
      aggregate_hardware(:hosts, :cpu_sockets, targets)
    end

    def aggregate_memory(targets = nil)
      aggregate_hardware(:hosts, :memory_mb, targets)
    end

    def aggregate_vm_cpus(targets = nil)
      aggregate_hardware(:vms_and_templates, :cpu_sockets, targets)
    end

    def aggregate_vm_memory(targets = nil)
      aggregate_hardware(:vms_and_templates, :memory_mb, targets)
    end

    def aggregate_disk_capacity(targets = nil)
      aggregate_hardware(:hosts, :disk_capacity, targets)
    end

    # Default implementations which can be overridden with something more optimized

    def all_storages
      hosts = all_hosts
      MiqPreloader.preload(hosts, :storages)
      hosts.collect(&:storages).flatten.compact.uniq
    end

    def aggregate_hardware(from, field, targets = nil)
      from      = from.to_s.singularize
      select    = field == :aggregate_cpu_speed ? "cpu_total_cores, cpu_speed" : field
      targets ||= send("all_#{from.pluralize}")
      hdws      = Hardware.where(from.singularize => targets).select(select)
      hdws.inject(0) { |t, hdw| t + hdw.send(field).to_i }
    end

    def lans
      hosts = all_hosts
      MiqPreloader.preload(hosts, :lans)
      hosts.flat_map(&:lans).compact.uniq
    end
  end
end
