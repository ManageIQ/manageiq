module AggregationMixin
  extend ActiveSupport::Concern
  included do
    virtual_column :aggregate_cpu_speed,     :type => :integer, :uses => :all_relationships
    virtual_column :aggregate_logical_cpus,  :type => :integer, :uses => :all_relationships
    virtual_column :aggregate_physical_cpus, :type => :integer, :uses => :all_relationships
    virtual_column :aggregate_memory,        :type => :integer, :uses => :all_relationships
    virtual_column :aggregate_vm_cpus,       :type => :integer, :uses => :all_relationships
    virtual_column :aggregate_vm_memory,     :type => :integer, :uses => :all_relationships

    # Helper method to override the virtual_column :uses definitions in the
    # event that the all_* methods are overridden
    def self.override_aggregation_mixin_virtual_columns_uses(type, new_uses)
      case type
      when :all_hosts
        virtual_columns_hash["aggregate_cpu_speed"].uses     = new_uses
        virtual_columns_hash["aggregate_logical_cpus"].uses  = new_uses
        virtual_columns_hash["aggregate_physical_cpus"].uses = new_uses
        virtual_columns_hash["aggregate_memory"].uses        = new_uses
      when :all_vms_and_templates
        virtual_columns_hash["aggregate_vm_cpus"].uses       = new_uses
        virtual_columns_hash["aggregate_vm_memory"].uses     = new_uses
      end
    end
  end

  def aggregate_cpu_speed(targets = nil)
    aggregate_hardware(:hosts, :aggregate_cpu_speed, targets)
  end

  def aggregate_logical_cpus(targets = nil)
    aggregate_hardware(:hosts, :logical_cpus, targets)
  end

  def aggregate_physical_cpus(targets = nil)
    aggregate_hardware(:hosts, :numvcpus, targets)
  end

  def aggregate_memory(targets = nil)
    aggregate_hardware(:hosts, :memory_cpu, targets)
  end

  def aggregate_vm_cpus(targets = nil)
    aggregate_hardware(:vms_and_templates, :numvcpus, targets)
  end

  def aggregate_vm_memory(targets = nil)
    aggregate_hardware(:vms_and_templates, :memory_cpu, targets)
  end

  # Default implementations which can be overridden with something more optimized

  def all_vms_and_templates
    self.descendants(:of_type => 'VmOrTemplate').sort_by { |v| v.name.downcase }
  end

  def all_vms
    all_vms_and_templates.select { |v| v.kind_of?(Vm) }
  end

  def all_miq_templates
    all_vms_and_templates.select { |v| v.kind_of?(MiqTemplate) }
  end

  def all_vm_or_template_ids
    Relationship.resource_pairs_to_ids(self.descendant_ids(:of_type => 'VmOrTemplate'))
  end

  def all_vm_ids
    all_vms.collect(&:id)
  end

  def all_miq_template_ids
    all_miq_templates.collect(&:id)
  end

  def all_hosts
    self.descendants(:of_type => 'Host').sort_by { |v| v.name.downcase }
  end

  def all_host_ids
    Relationship.resource_pairs_to_ids(self.descendant_ids(:of_type => 'Host'))
  end

  def all_storages
    hosts = self.all_hosts
    MiqPreloader.preload(hosts, :storages)
    hosts.collect { |h| h.storages }.flatten.compact.uniq
  end

  def aggregate_hardware(from, field, targets = nil)
    from      = from.to_s.singularize
    select    = field == :aggregate_cpu_speed ? "logical_cpus, cpu_speed" : field
    targets ||= self.send("all_#{from}_ids")
    targets   = targets.collect(&:id) unless targets.first.kind_of?(Integer)
    hdws      = Hardware.where("#{from}_id" => targets).select(select)

    hdws.inject(0) { |t, hdw| t + hdw.send(field).to_i }
  end
end
