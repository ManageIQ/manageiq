FactoryBot.define do
  factory :load_balancer do
    sequence(:name)    { |n| "load_balancer_#{seq_padded_for_sorting(n)}" }
    sequence(:ems_ref) { |n| "ems_ref_#{seq_padded_for_sorting(n)}" }
  end

  factory :load_balancer_amazon,
          :class  => "ManageIQ::Providers::Amazon::NetworkManager::LoadBalancer",
          :parent => :load_balancer
end
