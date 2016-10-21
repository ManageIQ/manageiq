class ManageIQ::Providers::StorageManager::SwiftManagerDecorator < Draper::Decorator
  delegate_all

  def listicon_image
    "svg/vendor-openstack.svg"
  end
end
