FactoryGirl.define do
  factory :template_vmware do
    sequence(:name) { |n| "template_#{seq_padded_for_sorting(n)}" }
    location        { |x| "[storage] #{x.name}/#{x.name}.vmtx" }
    uid_ems         { MiqUUID.new_guid }
    vendor          "vmware"
    template        true
    raw_power_state "never"
  end

  factory :template_vmware_with_ref, :parent => :template_vmware do
    sequence(:ems_ref)     { |n| "vm-#{seq_padded_for_sorting(n)}" }
    sequence(:ems_ref_obj) { |n| VimString.new("vm-#{seq_padded_for_sorting(n)}", "VirtualMachine", "ManagedObjectReference") }
  end
end
