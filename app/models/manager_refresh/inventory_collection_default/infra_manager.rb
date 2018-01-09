class ManagerRefresh::InventoryCollectionDefault::InfraManager < ManagerRefresh::InventoryCollectionDefault
  class << self
    def networks(extra_attributes = {})
      attributes = {
          :model_class => ::Network,
          :manager_ref => [:hardware, :ipaddress, :ipv6address],
          :association => :networks,
      }

      attributes.merge!(extra_attributes)
    end

    def host_networks(extra_attributes = {})
      attributes = {
          :model_class => ::Network,
          :manager_ref => [:hardware, :ipaddress],
          :association => :host_networks,
      }

      attributes.merge!(extra_attributes)
    end

    def guest_devices(extra_attributes = {})
      attributes = {
        :model_class => ::GuestDevice,
        :manager_ref => [:hardware, :uid_ems],
        :association => :guest_devices,
      }

      attributes.merge!(extra_attributes)
    end

    def host_hardwares(extra_attributes = {})
      attributes = {
        :model_class => ::Hardware,
        :manager_ref => [:host],
        :association => :host_hardwares,
      }

      attributes.merge!(extra_attributes)
    end

    def snapshots(extra_attributes = {})
      attributes = {
        :model_class => ::Snapshot,
        :manager_ref => [:uid],
        :association => :snapshots,
      }

      attributes.merge!(extra_attributes)
    end

    def operating_systems(extra_attributes = {})
      attributes = {
        :model_class => ::OperatingSystem,
        :manager_ref => [:vm_or_template],
        :association => :operating_systems,
      }

      attributes.merge!(extra_attributes)
    end

    def host_operating_systems(extra_attributes = {})
      attributes = {
        :model_class => ::OperatingSystem,
        :manager_ref => [:host],
        :association => :host_operating_systems,
      }

      attributes.merge!(extra_attributes)
    end

    def custom_attributes(extra_attributes = {})
      attributes = {
        :model_class => ::CustomAttribute,
        :manager_ref => [:name],
        :association => :custom_attributes,
      }

      attributes.merge!(extra_attributes)
    end

    def ems_folders(extra_attributes = {})
      attributes = {
        :model_class          => ::EmsFolder,
        :association          => :ems_folders,
        :manager_ref          => [:uid_ems],
        :attributes_blacklist => [:ems_children],
        :builder_params => {
          :ems_id => ->(persister) { persister.manager.id },
        },
      }

      attributes.merge!(extra_attributes)
    end

    def resource_pools(extra_attributes = {})
      attributes = {
        :model_class          => ::ResourcePool,
        :association          => :resource_pools,
        :manager_ref          => [:uid_ems],
        :attributes_blacklist => [:ems_children],
        :builder_params       => {
          :ems_id => ->(persister) { persister.manager.id },
        },
      }

      attributes.merge!(extra_attributes)
    end

    def ems_clusters(extra_attributes = {})
      attributes = {
        :model_class          => ::EmsCluster,
        :association          => :ems_clusters,
        :attributes_blacklist => [:ems_children, :datacenter_id],
        :builder_params       => {
          :ems_id => ->(persister) { persister.manager.id },
        },
      }

      attributes.merge!(extra_attributes)
    end

    def storages(extra_attributes = {})
      attributes = {
        :model_class => ::Storage,
        :manager_ref => [:location],
        :association => :storages,
        :complete    => false,
        :arel        => Storage
      }

      attributes.merge!(extra_attributes)
    end

    def hosts(extra_attributes = {})
      attributes = {
        :model_class    => ::Host,
        :association    => :hosts,
        :builder_params => {
          :ems_id => ->(persister) { persister.manager.id },
        },
        :custom_reconnect_block      => lambda do |inventory_collection, inventory_objects_index, attributes_index|
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
      }

      attributes.merge!(extra_attributes)
    end

    def vms(extra_attributes = {})
      attributes = {
        :custom_reconnect_block => lambda do |inventory_collection, inventory_objects_index, attributes_index|
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
      }

      super(attributes.merge!(extra_attributes))
    end

    def host_storages(extra_attributes = {})
      attributes = {
        :model_class => ::HostStorage,
        :manager_ref => [:host, :storage],
        :association => :host_storages,
      }

      attributes.merge!(extra_attributes)
    end

    def host_switches(extra_attributes = {})
      attributes = {
        :model_class => ::HostSwitch,
        :manager_ref => [:host, :switch],
        :association => :host_switches
      }

      attributes.merge!(extra_attributes)
    end

    def switches(extra_attributes = {})
      attributes = {
        :model_class => ::Switch,
        :manager_ref => [:uid_ems],
        :association => :switches,
      }

      attributes.merge!(extra_attributes)
    end

    def lans(extra_attributes = {})
      attributes = {
        :model_class => ::Lan,
        :manager_ref => [:uid_ems],
        :association => :lans,
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
