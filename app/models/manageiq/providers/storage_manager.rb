module ManageIQ::Providers
  class StorageManager < ManageIQ::Providers::BaseManager
    include SupportsFeatureMixin

    has_many :cloud_tenants, :foreign_key => :ems_id, :dependent => :destroy
    has_many :volume_availability_zones, :class_name => "AvailabilityZone", :foreign_key => :ems_id, :dependent => :destroy

    has_many :cloud_volumes, :foreign_key => :ems_id, :dependent => :destroy
    has_many :physical_storages, :foreign_key => "ems_id", :dependent => :destroy,
             :inverse_of => :ext_management_system
    has_many :storage_resources, :foreign_key => "ems_id", :dependent => :destroy,
             :inverse_of => :ext_management_system
    has_many :host_initiators, :foreign_key => "ems_id", :dependent => :destroy,
             :inverse_of => :ext_management_system
    has_many :host_initiator_groups, :foreign_key => "ems_id", :dependent => :destroy,
             :inverse_of => :ext_management_system
    has_many :volume_mappings, :foreign_key => "ems_id", :dependent => :destroy,
             :inverse_of => :ext_management_system
    has_many :san_addresses, :foreign_key => "ems_id", :dependent => :destroy,
             :inverse_of => :ext_management_system
    has_many :physical_storage_families, :foreign_key => :ems_id, :dependent => :destroy,
             :inverse_of => :ext_management_system
    has_many :storage_services, :foreign_key => "ems_id", :dependent => :destroy,
             :inverse_of => :ext_management_system
    has_many :storage_service_resource_attachments, :foreign_key => "ems_id",
             :dependent => :destroy, :inverse_of => :ext_management_system

    has_many :cloud_volume_snapshots, :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_volume_backups,   :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_volume_types,     :foreign_key => :ems_id, :dependent => :destroy

    has_many :cloud_object_store_containers, :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_object_store_objects,    :foreign_key => :ems_id

    has_many :wwpn_candidates, :foreign_key => :ems_id, :dependent => :destroy,
             :inverse_of => :ext_management_system

    belongs_to :parent_manager,
               :foreign_key => :parent_ems_id,
               :class_name  => "ManageIQ::Providers::BaseManager",
               :autosave    => true

    delegate :queue_name_for_ems_refresh, :to => :parent_manager

    def self.display_name(number = 1)
      n_('Storage Manager', 'Storage Managers', number)
    end

    class << model_name
      define_method(:route_key) { "ems_storages" }
      define_method(:singular_route_key) { "ems_storage" }
    end
  end
end
