module CloudObjectStoreObject::Operations
  extend ActiveSupport::Concern

  def cloud_object_store_object_delete
    raw_delete
  end

  def raw_delete
    raise NotImplementedError, _("must be implemented in subclass")
  end
end
