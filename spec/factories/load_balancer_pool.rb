FactoryBot.define do
  factory :load_balancer_pool do
    sequence(:name)    { |n| "load_balancer_pool_#{seq_padded_for_sorting(n)}" }
    sequence(:ems_ref) { |n| "ems_ref_#{seq_padded_for_sorting(n)}" }
  end

  factory :load_balancer_pool_amazon,
          :class  => "ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerPool",
          :parent => :load_balancer_pool
end
