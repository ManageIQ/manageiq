class ManageIQ::Providers::Openstack::InventoryCollectionDefault::CloudManager < ManagerRefresh::InventoryCollectionDefault::CloudManager
  class << self
    def cloud_tenants(extra_attributes = {})
      attributes = {
        :model_class => ManageIQ::Providers::Openstack::CloudManager::CloudTenant,
        :association => :cloud_tenants,
        :manager_ref => [:ems_ref],
      }
      attributes.merge!(extra_attributes)
    end

    def host_aggregates(extra_attributes = {})
      attributes = {
        :model_class => ManageIQ::Providers::Openstack::CloudManager::HostAggregate,
        :association => :host_aggregates,
        :manager_ref => [:ems_ref],
      }
      attributes.merge!(extra_attributes)
    end

    def cloud_volumes(extra_attributes = {})
      attributes = {
        :model_class => ManageIQ::Providers::Openstack::CloudManager::CloudVolume,
        :association => :cloud_volumes,
        :manager_ref => [:ems_ref],
      }
      attributes.merge!(extra_attributes)
    end

    def cloud_volume_snapshots(extra_attributes = {})
      attributes = {
        :model_class => ManageIQ::Providers::Openstack::CloudManager::CloudVolumeSnapshot,
        :association => :cloud_volume_snapshots,
        :manager_ref => [:ems_ref],
      }
      attributes.merge!(extra_attributes)
    end

    def cloud_volume_backups(extra_attributes = {})
      attributes = {
        :model_class => ManageIQ::Providers::Openstack::CloudManager::CloudVolumeBackup,
        :association => :cloud_volume_backups,
        :manager_ref => [:ems_ref],
      }
      attributes.merge!(extra_attributes)
    end

    def cloud_services(extra_attributes = {})
      attributes = {
        :model_class => CloudService,
        :association => :cloud_services,
        :manager_ref => [:ems_ref],
      }
      attributes.merge!(extra_attributes)
    end

    def cloud_resource_quotas(extra_attributes = {})
      attributes = {
        :model_class => CloudResourceQuota,
        :association => :cloud_resource_quotas,
        :manager_ref => [:ems_ref],
      }
      attributes.merge!(extra_attributes)
    end
  end
end
