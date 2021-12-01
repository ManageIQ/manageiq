FactoryBot.define do
  factory :container_node do
    sequence(:name) { |n| "container_node_#{seq_padded_for_sorting(n)}" }
    after(:create) do |x|
      x.computer_system = FactoryBot.create(:computer_system)
    end
  end

  factory :kubernetes_node,
          :aliases => ['app/models/manageiq/providers/kubernetes/container_manager/container_node'],
          :class   => 'ManageIQ::Providers::Kubernetes::ContainerManager::ContainerNode',
          :parent  => :container_node
end
