module Metric::ContainerStorage
  def self.fill_allocated_container_storage(obj)
    return {} unless obj.kind_of?(ContainerProject)

    sum_storage = obj.persistent_volume_claims.inject(0) do |sum, volume|
      sum + volume.capacity[:storage] if volume.capacity.present?
    end

    {
      :derived_vm_allocated_disk_storage => sum_storage
    }
  end
end
