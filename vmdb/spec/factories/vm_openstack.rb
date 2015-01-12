FactoryGirl.define do
  factory :vm_openstack, :class => "VmOpenstack", :parent => :vm_cloud do
    vendor          "openstack"
    raw_power_state "RUNNING"
  end

  factory :vm_perf_openstack, :parent => :vm_openstack do
    ems_ref         "openstack-perf-vm"
  end

  factory :vm_target_openstack, :parent => :vm_openstack do
    after(:create) { |x| x.raw_power_state = (toggle_on_name_seq(x) ? "RUNNING" : "STOPPED") }
  end
end
