class ManageIQ::Providers::StorageManager::CinderManagerDecorator < Draper::Decorator
  delegate_all

  def listicon_image
    "svg/vendor-openstack.svg"
  end
end
