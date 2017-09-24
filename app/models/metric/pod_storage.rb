  module Metric::PodStorage
  def self.fill_pod_allocated_storage(obj)
    return {} unless obj.kind_of? ContainerGroup

    sum_storage = obj.persistent_volumes.inject(0) {|sum, volume| sum + volume.capacity[:storage] if volume.capacity.present?}

    # feels like an integer overflow? volume.capacity[:storage] could be 10737418240
    {
      :derived_vm_allocated_disk_storage => sum_storage
    }
  end
end
