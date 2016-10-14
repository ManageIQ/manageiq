class ManageIQ::Providers::Kubernetes::ContainerManagerDecorator < Draper::Decorator
  delegate_all

  def listicon_image
    "svg/vendor-kubernetes.svg"
  end
end
