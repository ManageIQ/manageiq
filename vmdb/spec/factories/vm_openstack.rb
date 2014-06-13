FactoryGirl.define do
  factory :vm_openstack do
    sequence(:name) { |n| "vm_#{n}" }
    location        { |x| "[storage] #{x.name}/#{x.name}.vmx" }
    uid_ems         { MiqUUID.new_guid }
    vendor          "openstack"
    template        false
    power_state     "on"
    cloud           true
  end

  factory :vm_perf_openstack, :parent => :vm_openstack do
    ems_ref         "openstack-perf-vm"
  end

  factory :vm_target_openstack, :parent => :vm_openstack do
    after(:create) do |x|
      x.state = (toggle_on_name_seq(x) ? "on" : "off")
    end
  end
end
