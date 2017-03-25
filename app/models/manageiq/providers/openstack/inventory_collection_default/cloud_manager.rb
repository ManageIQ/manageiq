class ManageIQ::Providers::Openstack::InventoryCollectionDefault::CloudManager < ManagerRefresh::InventoryCollectionDefault::CloudManager
  class << self
    def availability_zones(extra_attributes = {})
      attributes = {
        :inventory_object_attributes => [
          :type,
          :ems_ref,
          :name
        ]
      }
      super(attributes.merge!(extra_attributes))
    end

    def cloud_resource_quotas(extra_attributes = {})
      attributes = {
        :model_class                 => CloudResourceQuota,
        :association                 => :cloud_resource_quotas,
        :manager_ref                 => [:ems_ref],
        :inventory_object_attributes => [
          :ems_ref,
          :type,
          :service_name,
          :name,
          :value,
          :cloud_tenant
        ]
      }
      attributes.merge!(extra_attributes)
    end

    def cloud_services(extra_attributes = {})
      attributes = {
        :model_class                 => CloudService,
        :association                 => :cloud_services,
        :manager_ref                 => [:ems_ref],
        :inventory_object_attributes => [
          :ems_ref,
          :source,
          :executable_name,
          :hostname,
          :status,
          :scheduling_disabled,
          :scheduling_disabled_reason,
          :host,
          :system_service,
          :availability_zone
        ]
      }
      attributes.merge!(extra_attributes)
    end

    def cloud_tenants(extra_attributes = {})
      attributes = {
        :model_class                 => ManageIQ::Providers::Openstack::CloudManager::CloudTenant,
        :association                 => :cloud_tenants,
        :manager_ref                 => [:ems_ref],
        :inventory_object_attributes => [
          :type,
          :name,
          :description,
          :enabled,
          :parent
        ]
      }
      attributes.merge!(extra_attributes)
    end

    def disks(extra_attributes = {})
      attributes = {
        :inventory_object_attributes => [
          :device_name,
          :device_type,
          :controller_type,
          :size,
          :location
        ]
      }
      super(attributes.merge!(extra_attributes))
    end

    def flavors(extra_attributes = {})
      attributes = {
        :inventory_object_attributes => [
          :type,
          :name,
          :enabled,
          :cpus,
          :memory,
          :publicly_available,
          :root_disk_size,
          :swap_disk_size,
          :ephemeral_disk_size,
          :ephemeral_disk_count,
          :cloud_tenants
        ]
      }
      super(attributes.merge!(extra_attributes))
    end

    def hardwares(extra_attributes = {})
      attributes = {
        :inventory_object_attributes => [
          :vm_or_template,
          :cpu_sockets,
          :cpu_total_cores,
          :cpu_speed,
          :memory_mb,
          :disk_capacity,
          :bitness,
          :disk_size_minimum,
          :memory_mb_minimum,
          :root_device_type,
          :size_on_disk,
          :virtualization_type
        ]
      }
      super(attributes.merge!(extra_attributes))
    end

    def host_aggregates(extra_attributes = {})
      attributes = {
        :model_class                 => ManageIQ::Providers::Openstack::CloudManager::HostAggregate,
        :association                 => :host_aggregates,
        :manager_ref                 => [:ems_ref],
        :inventory_object_attributes => [
          :type,
          :name,
          :metadata,
          :hosts
        ]
      }
      attributes.merge!(extra_attributes)
    end

    def key_pairs(extra_attributes = {})
      attributes = {
        :inventory_object_attributes => [
          :type,
          :name,
          :fingerprint
        ]
      }
      super(attributes.merge!(extra_attributes))
    end

    def miq_templates(extra_attributes = {})
      attributes = {
        :inventory_object_attributes => [
          :type,
          :uid_ems,
          :name,
          :vendor,
          :raw_power_state,
          :template,
          :publicly_available,
          :location,
          :cloud_tenant,
          :cloud_tenants,
          :genealogy_parent
        ]
      }
      super(attributes.merge!(extra_attributes))
    end

    def networks(extra_attributes = {})
      attributes = {
        :inventory_object_attributes => [
          :hardware,
          :description,
          :ipaddress
        ]
      }
      super(attributes.merge!(extra_attributes))
    end

    def orchestration_stacks_outputs(extra_attributes = {})
      attributes = {
        :inventory_object_attributes => [
          :ems_ref,
          :key,
          :value,
          :description,
          :stack
        ]
      }
      super(attributes.merge!(extra_attributes))
    end

    def orchestration_stacks_parameters(extra_attributes = {})
      attributes = {
        :inventory_object_attributes => [
          :ems_ref,
          :name,
          :value,
          :stack
        ]
      }
      super(attributes.merge!(extra_attributes))
    end

    def orchestration_stacks_resources(extra_attributes = {})
      attributes = {
        :inventory_object_attributes => [
          :ems_ref,
          :logical_resource,
          :physical_resource,
          :resource_category,
          :resource_status,
          :resource_status_reason,
          :last_updated,
          :stack
        ]
      }
      super(attributes.merge!(extra_attributes))
    end

    def orchestration_stacks(extra_attributes = {})
      attributes = {
        :inventory_object_attributes => [
          :type,
          :name,
          :description,
          :status,
          :status_reason,
          :parent,
          :orchestration_template,
          :cloud_tenant
        ]
      }
      super(attributes.merge!(extra_attributes))
    end

    def orchestration_templates(extra_attributes = {})
      attributes = {
        :inventory_object_attributes => [
          :type,
          :name,
          :description,
          :content,
          :orderable
        ]
      }
      super(attributes.merge!(extra_attributes))
    end

    def vms(extra_attributes = {})
      attributes = {
        :inventory_object_attributes => [
          :type,
          :uid_ems,
          :name,
          :vendor,
          :raw_power_state,
          :connection_state,
          :location,
          :host,
          :ems_cluster,
          :availability_zone,
          :key_pairs,
          :cloud_tenant,
          :parent,
          :flavor,
          :orchestration_stack
        ]
      }
      super(attributes.merge!(extra_attributes))
    end
  end
end
