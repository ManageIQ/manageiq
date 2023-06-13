FactoryBot.define do
  factory :container_node do
    transient do
      hardware { nil }
    end

    after(:create) do |cn, evaluator|
      unless evaluator.computer_system
        cn.computer_system = FactoryBot.create(:computer_system, :hardware => evaluator.hardware)
      end
    end
  end

  factory :kubernetes_node,
          :aliases => ['app/models/manageiq/providers/kubernetes/container_manager/container_node'],
          :class   => 'ManageIQ::Providers::Kubernetes::ContainerManager::ContainerNode',
          :parent  => :container_node
end
