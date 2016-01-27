class ManageIQ::Providers::Kubernetes::ContainerManagerDecorator < Draper::Decorator
  delegate_all

  def fonticon
    "pficon-kubernetes".freeze
  end
end
