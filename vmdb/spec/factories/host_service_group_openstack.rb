FactoryGirl.define do
  factory :host_service_group_openstack do
    sequence(:name) { |n| "host_service_group_openstack_#{seq_padded_for_sorting(n)}" }
  end
end
