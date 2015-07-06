FactoryGirl.define do
  factory :vm_or_template do
    sequence(:name) { |n| "vm_#{seq_padded_for_sorting(n)}" }
    location        "unknown"
    uid_ems         { MiqUUID.new_guid }
    vendor          "unknown"
    template        false
    raw_power_state "running"
  end

  factory :template, :class => "Template", :parent => :vm_or_template do
    sequence(:name) { |n| "template_#{seq_padded_for_sorting(n)}" }
    template        true
    raw_power_state "never"
  end

  factory(:vm,             :class => "Vm",            :parent => :vm_or_template)
  factory(:vm_cloud,       :class => "VmCloud",       :parent => :vm)       { cloud true }
  factory(:vm_infra,       :class => "VmInfra",       :parent => :vm)
  factory(:template_cloud, :class => "TemplateCloud", :parent => :template) { cloud true }
  factory(:template_infra, :class => "TemplateInfra", :parent => :template)
end
