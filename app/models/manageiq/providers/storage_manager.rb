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

    def cinder_service_available?
      raise NotImplementedError, _("cinder_service_available? must be implemented in a subclass")
    end

    def swift_service_available?
      raise NotImplementedError, _("swift_service_available? must be implemented in a subclass")
    end
  end
end
