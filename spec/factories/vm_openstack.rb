FactoryGirl.define do
  factory :vm_openstack, :class => "ManageIQ::Providers::Openstack::CloudManager::Vm", :parent => :vm_cloud do
    vendor          "openstack"
    raw_power_state "ACTIVE"
    sequence(:ems_ref) { |n| "some-uuid-#{seq_padded_for_sorting(n)}" }
    cloud_tenant { FactoryGirl.create(:cloud_tenant_openstack) }
  end

  factory :vm_perf_openstack, :parent => :vm_openstack do
    ems_ref         "openstack-perf-vm"
  end
end
