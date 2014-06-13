FactoryGirl.define do
  factory :template_vmware do
    sequence(:name) { |n| "template_#{n}" }
    location        { |x| "[storage] #{x.name}/#{x.name}.vmtx" }
    uid_ems         { MiqUUID.new_guid }
    vendor          "vmware"
    template        true
    state           "never"
  end

  factory :template_vmware_with_ref, :parent => :template_vmware do
    sequence(:ems_ref)     { |n| "vm-#{n}" }
    sequence(:ems_ref_obj) { |n| VimString.new("vm-#{n}", "VirtualMachine", "ManagedObjectReference") }
  end
end
