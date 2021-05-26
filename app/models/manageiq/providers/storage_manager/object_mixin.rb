module ManageIQ::Providers::StorageManager::ObjectMixin
  extend ActiveSupport::Concern

  included do
    supports :object_storage

    after_destroy :cleanup_objects

    private

    def cleanup_objects
      cloud_object_store_objects.includes(:taggings).find_each(&:destroy)
    end
  end
end
