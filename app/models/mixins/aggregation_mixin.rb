module AggregationMixin
  extend ActiveSupport::Concern
  included do
    virtual_column :aggregate_cpu_speed,       :type => :integer, :uses => :hosts
    virtual_column :aggregate_cpu_total_cores, :type => :integer, :uses => :hosts
    virtual_column :aggregate_physical_cpus,   :type => :integer, :uses => :hosts
    virtual_column :aggregate_memory,          :type => :integer, :uses => :hosts
    virtual_column :aggregate_vm_cpus,         :type => :integer, :uses => :vms_and_templates
    virtual_column :aggregate_vm_memory,       :type => :integer, :uses => :vms_and_templates
    virtual_column :aggregate_disk_capacity,   :type => :integer, :uses => :hosts

    alias_method :all_hosts,              :hosts
    alias_method :all_host_ids,           :host_ids
    alias_method :all_vms_and_templates,  :vms_and_templates
    alias_method :all_vm_or_template_ids, :vm_or_template_ids
    alias_method :all_vms,                :vms
    alias_method :all_vm_ids,             :vm_ids
    alias_method :all_miq_templates,      :miq_templates
    alias_method :all_miq_template_ids,   :miq_template_ids
  end

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
    targets ||= send("all_#{from}_ids")
    targets   = targets.collect(&:id) unless targets.first.kind_of?(Integer)
    hdws      = Hardware.where("#{from}_id" => targets).select(select)

    hdws.inject(0) { |t, hdw| t + hdw.send(field).to_i }
  end
end
