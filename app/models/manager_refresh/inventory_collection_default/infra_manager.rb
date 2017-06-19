class ManagerRefresh::InventoryCollectionDefault::InfraManager < ManagerRefresh::InventoryCollectionDefault
  class << self
    def vms(extra_attributes = {})
      attributes = {
        :model_class => ::ManageIQ::Providers::InfraManager::Vm,
        :association => :vms,
      }

      attributes.merge!(extra_attributes)
    end

    def miq_templates(extra_attributes = {})
      attributes = {
        :model_class => ::ManageIQ::Providers::InfraManager::Template,
        :association => :miq_templates,
      }

      attributes.merge!(extra_attributes)
    end

    def disks(extra_attributes = {})
      attributes = {
        :model_class => ::Disk,
        :manager_ref => [:hardware, :device_name],
        :association => :disks
      }

      attributes.merge!(extra_attributes)
    end

    def nics(extra_attributes = {})
      attributes = {
        :model_class => ::Network,
        :manager_ref => [:hardware, :ipaddress],
        :association => :nics
      }

      attributes.merge!(extra_attributes)
    end

    def guest_devices(extra_attributes = {})
      attributes = {
        :model_class => ::GuestDevice,
        :manager_ref => [:hardware, :uid_ems],
        :association => :guest_devices
      }

      attributes.merge!(extra_attributes)
    end

    def hardwares(extra_attributes = {})
      attributes = {
        :model_class => ::Hardware,
        :manager_ref => [:vm_or_template],
        :association => :hardwares
      }

      attributes.merge!(extra_attributes)
    end

    def snapshots(extra_attributes = {})
      attributes = {
        :model_class => ::Snapshot,
        :manager_ref => [:uid],
        :association => :snapshots
      }

      attributes.merge!(extra_attributes)
    end

    def operating_systems(extra_attributes = {})
      attributes = {
        :model_class => ::OperatingSystem,
        :manager_ref => [:vm_or_template],
        :association => :operating_systems
      }

      attributes.merge!(extra_attributes)
    end

    def custom_attributes(extra_attributes = {})
      attributes = {
        :model_class => ::CustomAttribute,
        :manager_ref => [:name],
        :association => :custom_attributes
      }

      attributes.merge!(extra_attributes)
    end

    def datacenters(extra_attributes = {})
      attributes = {
        :model_class          => ::Datacenter,
        :association          => :datacenters,
        :attributes_blacklist => [:ems_children]
      }

      attributes.merge!(extra_attributes)
    end

    def resource_pools(extra_attributes = {})
      attributes = {
        :model_class          => ::ResourcePool,
        :association          => :resource_pools,
        :manager_ref          => [:uid_ems],
        :attributes_blacklist => [:ems_children]
      }

      attributes.merge!(extra_attributes)
    end

    def ems_clusters(extra_attributes = {})
      attributes = {
        :model_class          => ::EmsCluster,
        :association          => :ems_clusters,
        :attributes_blacklist => [:ems_children, :datacenter_id]
      }

      attributes.merge!(extra_attributes)
    end

    def storages(extra_attributes = {})
      attributes = {
        :model_class => ::Storage,
        :association => :storages,
      }

      attributes.merge!(extra_attributes)
    end

    def hosts(extra_attributes = {})
      attributes = {
        :model_class => ::Host,
        :association => :hosts,
      }

      attributes.merge!(extra_attributes)
    end

    def datacenter_children(extra_attributes = {})
      datacenter_children_save_block = lambda do |_ems, inventory_collection|
        # TODO
      end

      attributes = {
        :association       => :datacenter_children,
        :custom_save_block => datacenter_children_save_block,
      }

      attributes.merge!(extra_attributes)
    end

    def resource_pool_children(extra_attributes = {})
      resource_pool_children_save_block = lambda do |_ems, inventory_collection|
        # TODO
      end

      attributes = {
        :association       => :resource_pool_children,
        :custom_save_block => resource_pool_children_save_block,
      }

      attributes.merge!(extra_attributes)
    end

    def ems_clusters_children(extra_attributes = {})
      ems_cluster_children_save_block = lambda do |_ems, inventory_collection|
        # TODO
      end

      attributes = {
        :association       => :ems_cluster_children,
        :custom_save_block => ems_cluster_children_save_block,
      }

      attributes.merge!(extra_attributes)
    end
  end
end
