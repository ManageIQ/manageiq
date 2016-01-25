class ManageIQ::Providers::OpenshiftEnterprise::ContainerManagerDecorator < Draper::Decorator
  delegate_all

  def fonticon
    "pficon pficon-openshift fa-lg".freeze
  end
end
