class ManagerRefresh::InventoryCollectionDefault::InfraManager < ManagerRefresh::InventoryCollectionDefault
  class << self
    def networks(extra_attributes = {})
      attributes = {
        :model_class                 => ::Network,
        :manager_ref                 => [:hardware, :ipaddress, :ipv6address],
        :association                 => :networks,
        :inventory_object_attributes => [
          :description,
          :hostname,
          :ipaddress,
          :subnet_mask,
          :ipv6address,
        ],
      }

      attributes.merge!(extra_attributes)
    end

    def host_networks(extra_attributes = {})
      attributes = {
        :model_class                 => ::Network,
        :manager_ref                 => [:hardware, :ipaddress],
        :association                 => :host_networks,
        :inventory_object_attributes => [
          :description,
          :hostname,
          :ipaddress,
          :subnet_mask
        ],
      }

      attributes.merge!(extra_attributes)
    end

    def guest_devices(extra_attributes = {})
      attributes = {
        :model_class                 => ::GuestDevice,
        :manager_ref                 => [:hardware, :uid_ems],
        :association                 => :guest_devices,
        :inventory_object_attributes => [
          :address,
          :controller_type,
          :device_name,
          :device_type,
          :lan,
          :location,
          :network,
          :present,
          :switch,
          :uid_ems
        ],
      }

      attributes.merge!(extra_attributes)
    end

    def host_hardwares(extra_attributes = {})
      attributes = {
        :model_class => ::Hardware,
        :manager_ref => [:host],
        :association => :host_hardwares,
        :inventory_object_attributes => [
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
          :serial_number
        ],
      }

      attributes.merge!(extra_attributes)
    end

    def snapshots(extra_attributes = {})
      attributes = {
        :model_class                 => ::Snapshot,
        :manager_ref                 => [:uid],
        :association                 => :snapshots,
        :inventory_object_attributes => [
          :uid_ems,
          :uid,
          :parent_uid,
          :name,
          :description,
          :create_time,
          :current,
          :vm_or_template
        ],
      }

      attributes.merge!(extra_attributes)
    end

    def operating_systems(extra_attributes = {})
      attributes = {
        :model_class                 => ::OperatingSystem,
        :manager_ref                 => [:vm_or_template],
        :association                 => :operating_systems,
        :inventory_object_attributes => [
          :name,
          :product_name,
          :product_type,
          :system_type,
          :version
        ],
      }

      attributes.merge!(extra_attributes)
    end

    def host_operating_systems(extra_attributes = {})
      attributes = {
        :model_class                 => ::OperatingSystem,
        :manager_ref                 => [:host],
        :association                 => :host_operating_systems,
        :inventory_object_attributes => [
          :name,
          :product_name,
          :product_type,
          :system_type,
          :version
        ],
      }

      attributes.merge!(extra_attributes)
    end

    def custom_attributes(extra_attributes = {})
      attributes = {
        :model_class                 => ::CustomAttribute,
        :manager_ref                 => [:name],
        :association                 => :custom_attributes,
        :inventory_object_attributes => [
          :section,
          :name,
          :value,
          :source,
        ],
      }

      attributes.merge!(extra_attributes)
    end

    def ems_folders(extra_attributes = {})
      attributes = {
        :model_class                 => ::EmsFolder,
        :association                 => :ems_folders,
        :manager_ref                 => [:uid_ems],
        :attributes_blacklist        => [:ems_children],
        :inventory_object_attributes => [
          :ems_ref,
          :name,
          :type,
          :uid_ems,
          :hidden
        ],
        :builder_params              => {
          :ems_id => ->(persister) { persister.manager.id },
        },
      }

      attributes.merge!(extra_attributes)
    end

    def datacenters(extra_attributes = {})
      attributes = {
        :model_class                 => ::Datacenter,
        :association                 => :datacenters,
        :inventory_object_attributes => [
          :name,
          :type,
          :uid_ems,
          :ems_ref,
          :ems_ref_obj,
          :hidden
        ],
        :builder_params              => {
          :ems_id => ->(persister) { persister.manager.id },
        },
      }

      attributes.merge!(extra_attributes)
    end

    def resource_pools(extra_attributes = {})
      attributes = {
        :model_class                 => ::ResourcePool,
        :association                 => :resource_pools,
        :manager_ref                 => [:uid_ems],
        :attributes_blacklist        => [:ems_children],
        :inventory_object_attributes => [
          :ems_ref,
          :name,
          :uid_ems,
          :is_default,
        ],
        :builder_params              => {
          :ems_id => ->(persister) { persister.manager.id },
        },
      }

      attributes.merge!(extra_attributes)
    end

    def ems_clusters(extra_attributes = {})
      attributes = {
        :model_class                 => ::EmsCluster,
        :association                 => :ems_clusters,
        :attributes_blacklist        => [:ems_children, :datacenter_id],
        :inventory_object_attributes => [
          :ems_ref,
          :ems_ref_obj,
          :uid_ems,
          :name,
          :datacenter_id,
        ],
        :builder_params              => {
          :ems_id => ->(persister) { persister.manager.id },
        },
      }

      attributes.merge!(extra_attributes)
    end

    def storages(extra_attributes = {})
      attributes = {
        :model_class                 => ::Storage,
        :manager_ref                 => [:location],
        :association                 => :storages,
        :complete                    => false,
        :arel                        => Storage,
        :inventory_object_attributes => [
          :ems_ref,
          :ems_ref_obj,
          :name,
          :store_type,
          :storage_domain_type,
          :total_space,
          :free_space,
          :uncommitted,
          :multiplehostaccess,
          :location,
          :master
        ],
      }

      attributes.merge!(extra_attributes)
    end

    def hosts(extra_attributes = {})
      attributes = {
        :model_class                 => ::Host,
        :association                 => :hosts,
        :inventory_object_attributes => [
          :type,
          :ems_ref,
          :ems_ref_obj,
          :name,
          :hostname,
          :ipaddress,
          :uid_ems,
          :vmm_vendor,
          :vmm_product,
          :vmm_version,
          :vmm_buildnumber,
          :connection_state,
          :power_state,
          :ems_cluster,
          :ipmi_address,
          :maintenance
        ],
        :builder_params              => {
          :ems_id => ->(persister) { persister.manager.id },
        },
        :custom_reconnect_block      => reconnect_block
      }

      attributes.merge!(extra_attributes)
    end

    def vms(extra_attributes = {})
      attributes = {
        :custom_reconnect_block => reconnect_block
      }

      super(attributes.merge!(extra_attributes))
    end

    def reconnect_block
      lambda do |inventory_collection, inventory_objects_index, attributes_index|
        relation = inventory_collection.model_class.where(:ems_id => nil)

        return if relation.count <= 0

        inventory_objects_index.each_slice(100) do |batch|
          relation.where(inventory_collection.manager_ref.first => batch.map(&:first)).each do |record|
            index = inventory_collection.object_index_with_keys(inventory_collection.manager_ref_to_cols, record)

            # We need to delete the record from the inventory_objects_index and attributes_index, otherwise it
            # would be sent for create.
            inventory_object = inventory_objects_index.delete(index)
            hash             = attributes_index.delete(index)

            record.assign_attributes(hash.except(:id, :type))
            if !inventory_collection.check_changed? || record.changed?
              record.save!
              inventory_collection.store_updated_records(record)
            end

            inventory_object.id = record.id
          end
        end
      end
    end

    def host_storages(extra_attributes = {})
      attributes = {
        :model_class                 => ::HostStorage,
        :manager_ref                 => [:host, :storage],
        :association                 => :host_storages,
        :inventory_object_attributes => [
          :ems_ref,
          :read_only,
          :host,
          :storage,
        ],
      }

      attributes.merge!(extra_attributes)
    end

    def host_switches(extra_attributes = {})
      attributes = {
        :model_class                 => ::HostSwitch,
        :manager_ref                 => [:host, :switch],
        :association                 => :host_switches,
        :inventory_object_attributes => [
          :host,
          :switch,
        ],
      }

      attributes.merge!(extra_attributes)
    end

    def switches(extra_attributes = {})
      attributes = {
        :model_class                 => ::Switch,
        :manager_ref                 => [:uid_ems],
        :association                 => :switches,
        :inventory_object_attributes => [
          :uid_ems,
          :name,
          :lans
        ],
      }

      attributes.merge!(extra_attributes)
    end

    def lans(extra_attributes = {})
      attributes = {
        :model_class                 => ::Lan,
        :manager_ref                 => [:uid_ems],
        :association                 => :lans,
        :inventory_object_attributes => [
          :name,
          :uid_ems,
          :tag
        ],
      }

      attributes.merge!(extra_attributes)
    end

    def snapshot_parent(extra_attributes = {})
      snapshot_parent_save_block = lambda do |_ems, inventory_collection|
        snapshot_collection = inventory_collection.dependency_attributes[:snapshots].try(:first)

        snapshot_collection.each do |snapshot|
          ActiveRecord::Base.transaction do
            child = Snapshot.find(snapshot.id)
            parent = Snapshot.find_by(:uid_ems => snapshot.parent_uid)
            child.update_attribute(:parent_id, parent.try(:id))
          end
        end
      end

      attributes = {
        :association       => :snapshot_patent,
        :custom_save_block => snapshot_parent_save_block,
      }

      attributes.merge!(extra_attributes)
    end
  end
end
