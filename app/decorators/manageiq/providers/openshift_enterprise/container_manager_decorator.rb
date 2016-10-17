class ManageIQ::Providers::OpenshiftEnterprise::ContainerManagerDecorator < Draper::Decorator
  delegate_all

  def listicon_image
    "svg/vendor-openshift_enterprise.svg"
  end
end
