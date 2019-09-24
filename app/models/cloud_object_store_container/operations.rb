module CloudObjectStoreContainer::Operations
  extend ActiveSupport::Concern

  def cloud_object_store_container_delete
    raw_delete
  end

  def raw_delete
    raise NotImplementedError, _("must be implemented in subclass")
  end

  def cloud_object_store_container_clear
    raw_cloud_object_store_container_clear
  end

  def raw_cloud_object_store_container_clear
    raise NotImplementedError, _("must be implemented in subclass")
  end
end
