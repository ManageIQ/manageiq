#
# StorageManager (hsong)
#
#

module ManageIQ::Providers
  class StorageManager < ManageIQ::Providers::BaseManager
    include SupportsFeatureMixin
    supports_not :smartstate_analysis
    supports_not :block_storage
    supports_not :object_storage
    supports_not :cloud_object_store_container_create
    supports_not :ems_storage_new

    has_many :cloud_tenants, :foreign_key => :ems_id, :dependent => :destroy
    has_many :volume_availability_zones, :class_name => "AvailabilityZone", :foreign_key => :ems_id, :dependent => :destroy

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

    # Allow only adding supported types. Non-supported types for adding will not be visible in the Type field
    def self.supported_types_and_descriptions_hash
      supported_subclasses.select(&:supports_ems_storage_new?).each_with_object({}) do |klass, hash|
        hash[klass.ems_type] = klass.description
      end
    end
  end
end
