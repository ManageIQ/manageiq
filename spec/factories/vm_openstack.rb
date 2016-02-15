FactoryGirl.define do
  factory :vm_openstack, :class => "ManageIQ::Providers::Openstack::CloudManager::Vm", :parent => :vm_cloud do
    vendor          "openstack"
    raw_power_state "ACTIVE"
    sequence(:ems_ref) { |n| "some-uuid-#{seq_padded_for_sorting(n)}" }
  end

  factory :vm_perf_openstack, :parent => :vm_openstack do
    ems_ref         "openstack-perf-vm"
  end

  factory :vm_target_openstack, :parent => :vm_openstack do
    after(:create) { |x| x.raw_power_state = (toggle_on_name_seq(x) ? "ACTIVE" : "SHUTOFF") }
  end
end
