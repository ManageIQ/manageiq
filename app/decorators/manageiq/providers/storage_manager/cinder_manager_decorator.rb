class ManageIQ::Providers::StorageManager::CinderManagerDecorator < Draper::Decorator
  delegate_all

  def fonticon
    nil
  end

  def listicon_image
    "100/vendor-openstack_storage.png"
  end
end
