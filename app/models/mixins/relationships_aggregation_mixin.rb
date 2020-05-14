module RelationshipsAggregationMixin
  extend ActiveSupport::Concern
  included do
    virtual_column :aggregate_cpu_speed,       :type => :integer, :uses => :all_relationships
    virtual_column :aggregate_cpu_total_cores, :type => :integer, :uses => :all_relationships
    virtual_column :aggregate_physical_cpus,   :type => :integer, :uses => :all_relationships
    virtual_column :aggregate_memory,          :type => :integer, :uses => :all_relationships
    virtual_column :aggregate_vm_cpus,         :type => :integer, :uses => :all_relationships
    virtual_column :aggregate_vm_memory,       :type => :integer, :uses => :all_relationships
    virtual_column :aggregate_disk_capacity,   :type => :integer, :uses => :all_relationships
  end

  # Default implementations which can be overridden with something more optimized

  def all_vms_and_templates
    descendants(:of_type => 'VmOrTemplate')
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
    descendants(:of_type => 'Host')
  end

  def all_host_ids
    Relationship.resource_pairs_to_ids(descendant_ids(:of_type => 'Host'))
  end
end
