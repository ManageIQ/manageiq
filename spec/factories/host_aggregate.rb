FactoryBot.define do
  factory :host_aggregate do
    sequence(:name) { |n| " host_aggregate_#{seq_padded_for_sorting(n)}" }
  end

  factory :host_aggregate_openstack, :parent => :host_aggregate, :class => "ManageIQ::Providers::Openstack::CloudManager::HostAggregate"
end
