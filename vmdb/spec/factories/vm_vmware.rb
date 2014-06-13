FactoryGirl.define do
  factory :vm_vmware do
    sequence(:name) { |n| "vm_#{n}" }
    location        { |x| "[storage] #{x.name}/#{x.name}.vmx" }
    uid_ems         { MiqUUID.new_guid }
    vendor          "vmware"
    template        false
    state           "on"
  end

  factory :vm_with_ref, :parent => :vm_vmware do
    sequence(:ems_ref)     { |n| "vm-#{n}" }
    sequence(:ems_ref_obj) { |n| VimString.new("vm-#{n}", "VirtualMachine", "ManagedObjectReference") }
  end

  # Factories for perf_capture, perf_process testing
  factory :vm_perf, :parent => :vm_vmware do
    name     "MIQ-WEBSVR1"
    location "MIQ-WEBSVR1/MIQ-WEBSVR1.vmx"
    ems_ref  "vm-578855"
    ems_ref_obj { VimString.new("vm-578855", "VirtualMachine", "ManagedObjectReference") }
  end

  # Factories for perf_capture_timer and perf_capture_gap testing
  factory :vm_target_vmware, :parent => :vm_vmware do
    after(:create) do |x|
      x.state = (toggle_on_name_seq(x) ? "on" : "off")
    end
  end
end
