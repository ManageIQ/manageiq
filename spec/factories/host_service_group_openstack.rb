FactoryBot.define do
  factory :host_service_group_openstack, :class => "ManageIQ::Providers::Openstack::InfraManager::HostServiceGroup" do
    sequence(:name) { |n| "host_service_group_openstack_#{seq_padded_for_sorting(n)}" }
  end
end
