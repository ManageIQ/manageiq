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
