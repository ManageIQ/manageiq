FactoryGirl.define do
  factory :container do
  end

  factory :kubernetes_container,
          :aliases => ['app/models/manageiq/providers/kubernetes/container_manager/container'],
          :class   => 'ManageIQ::Providers::Kubernetes::ContainerManager::Container',
          :parent  => :container do
  end
end
