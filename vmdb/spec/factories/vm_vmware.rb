FactoryGirl.define do
  factory :vm_vmware do
    sequence(:name) { |n| "vm_#{seq_padded_for_sorting(n)}" }
    location        { |x| "[storage] #{x.name}/#{x.name}.vmx" }
    uid_ems         { MiqUUID.new_guid }
    vendor          "vmware"
    template        false
    raw_power_state "poweredOn"
  end

  factory :vm_with_ref, :parent => :vm_vmware do
    sequence(:ems_ref)     { |n| "vm-#{seq_padded_for_sorting(n)}" }
    sequence(:ems_ref_obj) { |n| VimString.new("vm-#{seq_padded_for_sorting(n)}", "VirtualMachine", "ManagedObjectReference") }
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
      x.raw_power_state = (toggle_on_name_seq(x) ? "poweredOn" : "poweredOff")
    end
  end
end
