FactoryGirl.define do
  factory :template_vmware, :class => "TemplateVmware", :parent => "template_infra" do
    location { |x| "[storage] #{x.name}/#{x.name}.vmtx" }
    vendor   "vmware"
  end

  factory :template_vmware_with_ref, :parent => :template_vmware do
    sequence(:ems_ref)     { |n| "vm-#{seq_padded_for_sorting(n)}" }
    sequence(:ems_ref_obj) { |n| VimString.new("vm-#{seq_padded_for_sorting(n)}", "VirtualMachine", "ManagedObjectReference") }
  end
end
