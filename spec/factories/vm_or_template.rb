FactoryGirl.define do
  factory :vm_or_template do
    sequence(:name) { |n| "vm_#{seq_padded_for_sorting(n)}" }
    location        "unknown"
    uid_ems         { MiqUUID.new_guid }
    vendor          "unknown"
    template        false
    raw_power_state "running"
  end

  factory :template, :class => "MiqTemplate", :parent => :vm_or_template do
    sequence(:name) { |n| "template_#{seq_padded_for_sorting(n)}" }
    template        true
    raw_power_state "never"
  end

  factory(:vm, :class => "Vm", :parent => :vm_or_template)

  factory(:vm_orphaned, :class => "Vm", :parent => :vm_or_template) do
    ext_management_system nil
    storage_id            123
  end

  factory(:template_orphaned, :class => "TemplateInfra", :parent => :vm_or_template) do
    ext_management_system nil
    storage_id            123
  end

  factory(:vm_cloud_with_az, :class => "VmCloud", :parent => :vm) do
    ext_management_system { FactoryGirl.create(:ems_google) }
    storage_id            123
    availability_zone     { FactoryGirl.create(:availability_zone_google) }
  end

  factory(:vm_cloud_without_az, :class => "VmCloud", :parent => :vm) do
    ext_management_system { FactoryGirl.create(:ems_google) }
    storage_id            123
    availability_zone     nil
  end

  factory(:vm_infra_no_folder, :class => "VmInfra", :parent => :vm) do
    ext_management_system { FactoryGirl.create(:ems_infra) }
    storage_id             123
  end

  factory(:template_infra_no_folder, :class => "TemplateInfra", :parent => :template) do
    ext_management_system { FactoryGirl.create(:ems_infra) }
    storage_id            123
  end

  factory(:vm_cloud, :class => "VmCloud", :parent => :vm) { cloud true }
  factory(:vm_cloud_orphaned, :class => "VmCloud", :parent => :vm) do
    ext_management_system nil
    storage_id            123
    cloud                 true
  end
  factory(:vm_infra, :class => "VmInfra", :parent => :vm)
  factory(:template_cloud, :class => "TemplateCloud", :parent => :template) { cloud true }
  factory(:template_cloud_orphaned, :class => "TemplateCloud", :parent => :template) do
    ext_management_system nil
    storage_id            123
    cloud                 true
  end
  factory(:template_cloud_with_ems, :class => "TemplateCloud", :parent => :template) do
    ext_management_system { FactoryGirl.create(:ems_google) }
    storage_id            123
    cloud                 true
  end

  factory(:template_infra, :class => "TemplateInfra", :parent => :template)

  factory :template_openstack, :class => "ManageIQ::Providers::Openstack::CloudManager::Template", :parent => :template_cloud do
    vendor "openstack"
  end

  factory :template_amazon, :class => "ManageIQ::Providers::Amazon::CloudManager::Template", :parent => :template_cloud do
    location { |x| "#{x.name}/#{x.name}.img.manifest.xml" }
    vendor   "amazon"
  end
end
