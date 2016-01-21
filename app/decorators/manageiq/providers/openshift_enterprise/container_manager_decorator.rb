class ManageIQ::Providers::OpenshiftEnterprise::ContainerManagerDecorator < Draper::Decorator
  delegate_all

  def fonticon
    "pficon-openshift".freeze
  end
end
