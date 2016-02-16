module AggregationMixin
  extend ActiveSupport::Concern
  included do
    virtual_column :aggregate_cpu_speed,       :type => :integer, :uses => :all_relationships
    virtual_column :aggregate_cpu_total_cores, :type => :integer, :uses => :all_relationships
    virtual_column :aggregate_physical_cpus,   :type => :integer, :uses => :all_relationships
    virtual_column :aggregate_memory,          :type => :integer, :uses => :all_relationships
    virtual_column :aggregate_vm_cpus,         :type => :integer, :uses => :all_relationships
    virtual_column :aggregate_vm_memory,       :type => :integer, :uses => :all_relationships
    virtual_column :aggregate_disk_capacity,   :type => :integer, :uses => :all_relationships

    virtual_column :aggregate_logical_cpus, :type => :integer, :uses => :all_relationships # Deprecated

    # Helper method to override the virtual_column :uses definitions in the
    # event that the all_* methods are overridden
    def self.override_aggregation_mixin_virtual_columns_uses(type, new_uses)
      case type
      when :all_hosts
        define_virtual_include "aggregate_cpu_speed",       new_uses
        define_virtual_include "aggregate_cpu_total_cores", new_uses
        define_virtual_include "aggregate_physical_cpus",   new_uses
        define_virtual_include "aggregate_memory",          new_uses
        define_virtual_include "aggregate_disk_capacity",   new_uses

        define_virtual_include "aggregate_logical_cpus", new_uses # Deprecated

      when :all_vms_and_templates
        define_virtual_include "aggregate_vm_cpus",   new_uses
        define_virtual_include "aggregate_vm_memory", new_uses
      end
    end
  end

  def aggregate_cpu_speed(targets = nil)
    aggregate_hardware(:hosts, :aggregate_cpu_speed, targets)
  end

  def aggregate_cpu_total_cores(targets = nil)
    aggregate_hardware(:hosts, :cpu_total_cores, targets)
  end
  alias_method :aggregate_logical_cpus, :aggregate_cpu_total_cores
  Vmdb::Deprecation.deprecate_methods(self, :aggregate_logical_cpus => :aggregate_cpu_total_cores)

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

  def all_vms_and_templates
    descendants(:of_type => 'VmOrTemplate').sort_by { |v| v.name.downcase }
  end

  def all_vms
    all_vms_and_templates.select { |v| v.kind_of?(Vm) }
  end

  def all_miq_templates
    all_vms_and_templates.select { |v| v.kind_of?(MiqTemplate) }
  end

  def all_vm_or_template_ids
    Relationship.resource_pairs_to_ids(descendant_ids(:of_type => 'VmOrTemplate'))
  end

  def all_vm_ids
    all_vms.collect(&:id)
  end

  def all_miq_template_ids
    all_miq_templates.collect(&:id)
  end

  def all_hosts
    descendants(:of_type => 'Host').sort_by { |v| v.name.downcase }
  end

  def all_host_ids
    Relationship.resource_pairs_to_ids(descendant_ids(:of_type => 'Host'))
  end

  def all_storages
    hosts = all_hosts
    MiqPreloader.preload(hosts, :storages)
    hosts.collect(&:storages).flatten.compact.uniq
  end

  def aggregate_hardware(from, field, targets = nil)
    from      = from.to_s.singularize
    select    = field == :aggregate_cpu_speed ? "cpu_total_cores, cpu_speed" : field
    targets ||= send("all_#{from}_ids")
    targets   = targets.collect(&:id) unless targets.first.kind_of?(Integer)
    hdws      = Hardware.where("#{from}_id" => targets).select(select)

    hdws.inject(0) { |t, hdw| t + hdw.send(field).to_i }
  end
end
