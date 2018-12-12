FactoryBot.define do
  factory :load_balancer_listener do
    sequence(:name)    { |n| "load_balancer_listener_#{seq_padded_for_sorting(n)}" }
    sequence(:ems_ref) { |n| "ems_ref_#{seq_padded_for_sorting(n)}" }
  end

  factory :load_balancer_listener_amazon,
          :class  => "ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerListener",
          :parent => :load_balancer_listener
end
