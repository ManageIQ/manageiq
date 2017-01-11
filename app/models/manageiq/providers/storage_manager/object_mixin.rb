module ManageIQ::Providers::StorageManager::ObjectMixin
  extend ActiveSupport::Concern

  included do
    has_many :cloud_object_store_containers, :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_object_store_objects,    :foreign_key => :ems_id, :dependent => :destroy

    supports :object_storage
  end
end
