class ManageIQ::Providers::Openshift::ContainerManagerDecorator < Draper::Decorator
  delegate_all

  def fonticon
    "pficon pficon-openshift fa-lg".freeze
  end
end
