module Service::Aggregation
  extend ActiveSupport::Concern

  included do
    virtual_column :aggregate_direct_vm_cpus,                 :type => :integer
    virtual_column :aggregate_direct_vm_memory,               :type => :integer
    virtual_column :aggregate_direct_vm_disk_count,           :type => :integer
    virtual_column :aggregate_direct_vm_disk_space_allocated, :type => :integer
    virtual_column :aggregate_direct_vm_disk_space_used,      :type => :integer
    virtual_column :aggregate_direct_vm_memory_on_disk,       :type => :integer

    virtual_attribute :aggregate_all_vm_cpus,   :integer,
                      :arel => aggregate_service_hardware_arel('cpus', :cpu_total_cores)
    virtual_attribute :aggregate_all_vm_memory, :integer,
                      :arel => aggregate_service_hardware_arel('memory', :memory_mb)
    virtual_attribute :aggregate_all_vm_disk_count, :integer,
                      :arel => aggregate_all_vms_disk_count_arel
    virtual_attribute :aggregate_all_vm_disk_space_allocated, :integer,
                      :arel => aggregate_all_vms_disk_space_allocated_arel
    virtual_attribute :aggregate_all_vm_disk_space_used, :integer,
                      :arel => aggregate_all_vms_disk_space_used_arel
    virtual_attribute :aggregate_all_vm_memory_on_disk, :integer,
                      :arel => aggregate_service_hardware_arel('memory_on_disk', :memory_mb, :on_vms_only => true)

    AGGREGATE_ALL_VM_ATTRS = [
      :aggregate_all_vm_cpus,
      :aggregate_all_vm_memory,
      :aggregate_all_vm_disk_count,
      :aggregate_all_vm_disk_space_allocated,
      :aggregate_all_vm_disk_space_used,
      :aggregate_all_vm_memory_on_disk
    ].freeze

    scope :with_aggregates, -> { select(Arel.star, *AGGREGATE_ALL_VM_ATTRS) }
  end

  module ClassMethods
    def aggregate_service_hardware_arel(aggregate_alias, hardware_column, options = {})
      virtual_column_name = "aggregate_all_vm_#{aggregate_alias}"
      aggregation_sql = hardwares_tbl[hardware_column].sum
      aggregate_hardware_arel(virtual_column_name, aggregation_sql, options)
    end

    def aggregate_all_vms_disk_count_arel
      virtual_column_name = "aggregate_all_vm_disk_count"
      aggregation_sql = disks_tbl[:id].count
      aggregate_hardware_arel(virtual_column_name, aggregation_sql, :include_disks => true)
    end

    def aggregate_all_vms_disk_space_allocated_arel
      column_name     = "aggregate_all_vm_disk_space_allocated"
      coalesce_values = [disks_tbl[:size], zero]
      aggregation_sql = Arel::Nodes::NamedFunction.new('SUM',
                                                       [Arel::Nodes::NamedFunction.new('COALESCE', coalesce_values)])
      aggregate_hardware_arel(column_name, aggregation_sql, :include_disks => true)
    end

    def aggregate_all_vms_disk_space_used_arel
      column_name     = "aggregate_all_vm_disk_space_used"
      coalesce_values = [disks_tbl[:size_on_disk], disks_tbl[:size], zero]
      aggregation_sql = Arel::Nodes::NamedFunction.new('SUM',
                                                       [Arel::Nodes::NamedFunction.new('COALESCE', coalesce_values)])
      aggregate_hardware_arel(column_name, aggregation_sql, :include_disks => true)
    end

    def aggregate_hardware_arel(virtual_column_name, aggregation_sql, options = {})
      lambda do |t|
        subtree_services             = Arel::Table.new(:services)
        subtree_services.table_alias = "#{virtual_column_name}_services"

        subselect = subtree_services.project(aggregation_sql)
        subselect = base_service_aggregation_join(subselect, subtree_services, options)
        join_on_disks(subselect) if options[:include_disks]

        subselect.where(aggregation_where_clause(t, subtree_services))
      end
    end

    def aggregation_where_clause(arel, subtree_services)
      arel.grouping(
        subtree_services[:id].eq(arel[:id])
         .or(subtree_services[:ancestry].matches(ancestry_ilike))
      ).or(subtree_services[:ancestry].eq(service_id_cast))
    end

    def base_service_aggregation_join(arel, services_tbl, options = {})
      arel.join(service_resources_tbl).on(service_resources_tbl[:service_id].eq(services_tbl[:id])
                                  .and(service_resources_tbl[:resource_type].eq(vm_or_template_type)))
          .join(vms_tbl).on(vm_join_clause(options))
          .join(hardwares_tbl).on(hardwares_tbl[:vm_or_template_id].eq(vms_tbl[:id]))
    end

    def vm_join_clause(options = {})
      clause = vms_tbl[:id].eq(service_resources_tbl[:resource_id])
      if options[:on_vms_only] # meaning VMs that are powered "on"
        clause = clause.and(vms_tbl[:power_state].lower.eq('on'))
      end
      clause
    end

    def join_on_disks(arel)
      arel.join(disks_tbl).on(disks_tbl[:hardware_id].eq(hardwares_tbl[:id]))
    end

    # NOTE: The following class methods are technically "constants", but to
    # make sure they are not triggered when the class is first loaded and cause
    # requests to the DB (can break building the appliance), we are making them
    # memoized class methods.

    def service_resources_tbl
      @service_resources_tbl ||= ServiceResource.arel_table
    end

    def vms_tbl
      @vms_tbl ||= Vm.arel_table
    end

    def hardwares_tbl
      @hardwares_tbl ||= Hardware.arel_table
    end

    def disks_tbl
      @disks_tbl ||= Disk.arel_table
    end

    def partitions_tbl
      @partitions_tbl ||= Partition.arel_table
    end

    def zero
      @zero ||= Arel::Nodes::SqlLiteral.new("0")
    end

    def vm_or_template_type
      @vm_or_template_type ||= Arel::Nodes::SqlLiteral.new("'VmOrTemplate'")
    end

    def ancestry_match
      @ancestry_match ||= Arel::Nodes::SqlLiteral.new("'/%'")
    end

    def ancestry_ilike
      @ancestry_ilike ||= Arel::Nodes::NamedFunction.new("CONCAT", [Service.arel_table[:id], ancestry_match])
    end

    def service_id_cast
      @service_id_cast ||= Arel::Nodes::NamedFunction.new("CAST", [Service.arel_table[:id].as("VARCHAR")])
    end
  end

  def aggregate_direct_vm_cpus
    direct_vms.inject(0) { |aggregate, vm| aggregate + vm.cpu_total_cores.to_i }
  end

  def aggregate_direct_vm_memory
    direct_vms.inject(0) { |aggregate, vm| aggregate + vm.ram_size.to_i }
  end

  def aggregate_direct_vm_disk_count
    direct_vms.inject(0) { |aggregate, vm| aggregate + vm.num_disks.to_i }
  end

  def aggregate_direct_vm_disk_space_allocated
    direct_vms.inject(0) { |aggregate, vm| aggregate + vm.allocated_disk_storage.to_i }
  end

  def aggregate_direct_vm_disk_space_used
    direct_vms.inject(0) { |aggregate, vm| aggregate + vm.used_disk_storage.to_i }
  end

  def aggregate_direct_vm_memory_on_disk
    direct_vms.inject(0) { |aggregate, vm| aggregate + vm.ram_size_in_bytes_by_state.to_i }
  end

  def aggregate_all_vm_cpus
    if has_attribute?("aggregate_all_vm_cpus")
      self["aggregate_all_vm_cpus"]
    else
      all_vms.inject(0) { |aggregate, vm| aggregate + vm.cpu_total_cores.to_i }
    end
  end

  def aggregate_all_vm_memory
    if has_attribute?("aggregate_all_vm_memory")
      self["aggregate_all_vm_memory"]
    else
      all_vms.inject(0) { |aggregate, vm| aggregate + vm.ram_size.to_i }
    end
  end

  def aggregate_all_vm_disk_count
    if has_attribute?("aggregate_all_vm_disk_count")
      self["aggregate_all_vm_disk_count"]
    else
      all_vms.inject(0) { |aggregate, vm| aggregate + vm.num_disks.to_i }
    end
  end

  def aggregate_all_vm_disk_space_allocated
    if has_attribute?("aggregate_all_vm_disk_space_allocated")
      self["aggregate_all_vm_disk_space_allocated"]
    else
      all_vms.inject(0) { |aggregate, vm| aggregate + vm.allocated_disk_storage.to_i }
    end
  end

  def aggregate_all_vm_disk_space_used
    if has_attribute?("aggregate_all_vm_disk_space_used")
      self["aggregate_all_vm_disk_space_used"]
    else
      all_vms.inject(0) { |aggregate, vm| aggregate + vm.used_disk_storage.to_i }
    end
  end

  def aggregate_all_vm_memory_on_disk
    if has_attribute?("aggregate_all_vm_memory_on_disk")
      # Avoids (poorly) "ERROR:  integer out of range" in postgres
      self["aggregate_all_vm_memory_on_disk"] * 1.megabyte
    else
      all_vms.inject(0) { |aggregate, vm| aggregate + vm.ram_size_in_bytes_by_state.to_i }
    end
  end
end
