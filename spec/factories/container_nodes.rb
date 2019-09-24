FactoryBot.define do
  factory :container_node do
    after(:create) do |x|
      x.computer_system = FactoryBot.create(:computer_system)
    end
  end

  factory :kubernetes_node,
          :aliases => ['app/models/manageiq/providers/kubernetes/container_manager/container_node'],
          :class   => 'ManageIQ::Providers::Kubernetes::ContainerManager::ContainerNode',
          :parent  => :container_node
end
