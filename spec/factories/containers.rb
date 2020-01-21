FactoryBot.define do
  factory :container do
    sequence(:name) { |n| "container_#{seq_padded_for_sorting(n)}" }
  end

  factory :kubernetes_container,
          :aliases => ['app/models/manageiq/providers/kubernetes/container_manager/container'],
          :class   => 'ManageIQ::Providers::Kubernetes::ContainerManager::Container',
          :parent  => :container
end
