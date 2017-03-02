module CloudObjectStoreContainer::Operations
  extend ActiveSupport::Concern

  def delete_cloud_object_store_container
    raw_delete
  end

  def raw_delete
    raise NotImplementedError, _("must be implemented in subclass")
  end
end
