class ManagerRefresh::InventoryCollectionDefault::StorageManager < ManagerRefresh::InventoryCollectionDefault
  class << self
    def cloud_volumes(extra_attributes = {})
      attributes = {
        :model_class => ::CloudVolume,
        :association => :cloud_volumes,
      }

      attributes.merge!(extra_attributes)
    end

    def cloud_volume_snapshots(extra_attributes = {})
      attributes = {
        :model_class => ::CloudVolumeSnapshot,
        :association => :cloud_volume_snapshots,
      }

      attributes.merge!(extra_attributes)
    end

    def cloud_object_store_containers(extra_attributes = {})
      attributes = {
        :model_class => ::CloudObjectStoreContainer,
        :association => :cloud_object_store_containers,
      }

      attributes.merge!(extra_attributes)
    end

    def cloud_object_store_objects(extra_attributes = {})
      attributes = {
        :model_class => ::CloudObjectStoreObject,
        :association => :cloud_object_store_objects,
      }

      attributes.merge!(extra_attributes)
    end
  end
end
