module ManagerRefresh::Inventory::CloudManager
  extend ActiveSupport::Concern
  include ::ManagerRefresh::Inventory::Core

  class_methods do
    def has_cloud_manager_vms(options = {})
      has_vms({
        :model_class    => provider_module::CloudManager::Vm,
        :association    => :vms,
        :builder_params => {
          :ext_management_system => ->(persister) { persister.manager }
        },
      }.merge(options))
    end
  end
end
