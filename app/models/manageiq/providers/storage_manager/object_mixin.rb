module ManageIQ::Providers::StorageManager::ObjectMixin
  extend ActiveSupport::Concern

  included do
    has_many :cloud_object_store_containers, :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_object_store_objects,    :foreign_key => :ems_id

    supports :object_storage

    after_destroy :cleanup_objects

    private

    def cleanup_objects
      cloud_object_store_objects.includes(:taggings).find_each(&:destroy)
    end
  end
end
