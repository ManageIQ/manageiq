FactoryGirl.define do
  factory :vm_openstack do
    sequence(:name) { |n| "vm_#{n}" }
    location        { |x| "[storage] #{x.name}/#{x.name}.vmx" }
    uid_ems         { MiqUUID.new_guid }
    vendor          "openstack"
    template        false
    raw_power_state "RUNNING"
    cloud           true
  end

  factory :vm_perf_openstack, :parent => :vm_openstack do
    ems_ref         "openstack-perf-vm"
  end

  factory :vm_target_openstack, :parent => :vm_openstack do
    after(:create) do |x|
      x.raw_power_state = (toggle_on_name_seq(x) ? "RUNNING" : "STOPPED")
    end
  end
end
