module ActiveVmAggregationMixin
  extend ActiveSupport::Concern
  included do
    virtual_column :allocated_memory,   :type => :integer, :uses => :active_vms
    virtual_column :allocated_vcpu,     :type => :integer, :uses => :active_vms
    virtual_column :allocated_storage,  :type => :integer, :uses => :active_vms
    virtual_column :provisioned_storage,:type => :integer, :uses => :active_vms

    virtual_has_many :active_vms, :class_name => "VmOrTemplate", :uses  => :vms
  end

  def active_vms
    self.vms.select(&:active?)
  end

  def active_vm_aggregation(field_name)
    active_vms.inject(0) { |t, vm| t + vm.send(field_name).to_i }
  end

  def allocated_memory
    active_vm_aggregation(:ram_size_in_bytes)
  end

  def allocated_vcpu
    active_vm_aggregation(:num_cpu)
  end

  def allocated_storage
    active_vm_aggregation(:allocated_disk_storage)
  end

  def provisioned_storage
    active_vm_aggregation(:provisioned_storage)
  end
end
