class ManageIQ::Providers::Openshift::ContainerManagerDecorator < Draper::Decorator
  delegate_all

  def listicon_image
    "svg/vendor-openshift.svg"
  end
end
