class ManagerRefresh::InventoryCollectionDefault
  class << self
    def vms(extra_attributes = {})
      attributes = {
        :model_class                 => ::Vm,
        :association                 => :vms,
        :delete_method               => :disconnect_inv,
        :attributes_blacklist        => [:genealogy_parent],
        :use_ar_object               => true, # Because of raw_power_state setter and hooks are needed for settings user
        # TODO(lsmola) can't do batch strategy for vms because of key_pairs relation
        :saver_strategy              => :default,
        :batch_extra_attributes      => [:power_state, :state_changed_on, :previous_state],
        :inventory_object_attributes => [
          :type,
          :cpu_limit,
          :cpu_reserve,
          :cpu_reserve_expand,
          :cpu_shares,
          :cpu_shares_level,
          :ems_ref,
          :ems_ref_obj,
          :uid_ems,
          :connection_state,
          :vendor,
          :name,
          :location,
          :template,
          :memory_limit,
          :memory_reserve,
          :memory_reserve_expand,
          :memory_shares,
          :memory_shares_level,
          :raw_power_state,
          :boot_time,
          :host,
          :ems_cluster,
          :storages,
          :storage,
          :snapshots
        ],
        :builder_params              => {
          :ems_id   => ->(persister) { persister.manager.id },
          :name     => "unknown",
          :location => "unknown",
        }
      }

      attributes.merge!(extra_attributes)
    end

    def miq_templates(extra_attributes = {})
      attributes = {
        :model_class                 => ::MiqTemplate,
        :association                 => :miq_templates,
        :delete_method               => :disconnect_inv,
        :attributes_blacklist        => [:genealogy_parent],
        :use_ar_object               => true, # Because of raw_power_state setter
        :saver_strategy              => :default, # Hooks are needed for setting user
        :batch_extra_attributes      => [:power_state, :state_changed_on, :previous_state],
        :inventory_object_attributes => [
          :type,
          :ems_ref,
          :ems_ref_obj,
          :uid_ems,
          :connection_state,
          :vendor,
          :name,
          :location,
          :template,
          :memory_limit,
          :memory_reserve,
          :raw_power_state,
          :boot_time,
          :host,
          :ems_cluster,
          :storages,
          :storage,
          :snapshots
        ],
        :builder_params              => {
          :ems_id   => ->(persister) { persister.manager.id },
          :name     => "unknown",
          :location => "unknown",
          :template => true
        }
      }

      attributes.merge!(extra_attributes)
    end

    def hardwares(extra_attributes = {})
      attributes = {
        :model_class                  => ::Hardware,
        :manager_ref                  => [:vm_or_template],
        :association                  => :hardwares,
        :parent_inventory_collections => [:vms, :miq_templates],
        :inventory_object_attributes  => [
          :annotation,
          :cpu_cores_per_socket,
          :cpu_sockets,
          :cpu_speed,
          :cpu_total_cores,
          :cpu_type,
          :guest_os,
          :manufacturer,
          :memory_mb,
          :model,
          :networks,
          :number_of_nics,
          :serial_number,
          :virtual_hw_version
        ],
        # TODO(lsmola) just because of default value on cpu_sockets, this can be fixed by separating instances_hardwares and images_hardwares
        :use_ar_object                => true,
      }

      attributes.merge!(extra_attributes)
    end

    def operating_systems(extra_attributes = {})
      attributes = {
        :model_class                  => ::OperatingSystem,
        :manager_ref                  => [:vm_or_template],
        :association                  => :operating_systems,
        :parent_inventory_collections => [:vms, :miq_templates],
        :inventory_object_attributes  => [
          :name,
          :product_name,
          :product_type,
          :system_type,
          :version
        ],
      }

      attributes.merge!(extra_attributes)
    end

    def disks(extra_attributes = {})
      attributes = {
        :model_class                  => ::Disk,
        :manager_ref                  => [:hardware, :device_name],
        :association                  => :disks,
        :parent_inventory_collections => [:vms],
        :inventory_object_attributes  => [
          :device_name,
          :device_type,
          :controller_type,
          :present,
          :filename,
          :location,
          :size,
          :size_on_disk,
          :disk_type,
          :mode,
          :bootable,
          :storage
        ],
      }

      attributes.merge!(extra_attributes)
    end
  end
end
