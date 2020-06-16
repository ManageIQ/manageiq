FactoryBot.define do
  factory :vm_or_template do
    sequence(:name) { |n| "vm_#{seq_padded_for_sorting(n)}" }
    location        { "unknown" }
    uid_ems         { SecureRandom.uuid }
    vendor          { "unknown" }
    template        { false }
    raw_power_state { "running" }

    trait :in_other_region do
      other_region
    end
  end

  factory :template, :class => "MiqTemplate", :parent => :vm_or_template do
    sequence(:name) { |n| "template_#{seq_padded_for_sorting(n)}" }
    template        { true }
    raw_power_state { "never" }
  end

  factory(:vm,             :class => "Vm",            :parent => :vm_or_template)
  factory(:vm_cloud,       :class => "VmCloud",       :parent => :vm)       { cloud { true } }
  factory(:vm_infra,       :class => "VmInfra",       :parent => :vm)
  factory(:vm_server,      :class => "VmServer",      :parent => :vm)
  factory(:template_cloud, :class => "TemplateCloud", :parent => :template) { cloud { true } }
  factory(:template_infra, :class => "TemplateInfra", :parent => :template)

  factory :template_amazon, :class => "ManageIQ::Providers::Amazon::CloudManager::Template", :parent => :template_cloud do
    location { |x| "#{x.name}/#{x.name}.img.manifest.xml" }
    vendor   { "amazon" }
  end

  factory :template_openstack, :class => "ManageIQ::Providers::Openstack::CloudManager::Template", :parent => :template_cloud do
    vendor { "openstack" }
  end

  factory :volume_template_openstack, :class => "ManageIQ::Providers::Openstack::CloudManager::VolumeTemplate", :parent => :template_cloud do
    vendor { "openstack" }
  end

  factory :miq_template do
    name { "ubuntu-16.04-stable" }
    location { "Minneapolis, MN" }
    vendor { "openstack" }
  end

  factory :template_azure, :class => "ManageIQ::Providers::Azure::CloudManager::Template", :parent => :template_cloud do
    location { |x| "#{x.name}/#{x.name}.img.manifest.xml" }
    vendor   { "azure" }
  end

  factory(:template_google, :class => "ManageIQ::Providers::Google::CloudManager::Template", :parent => :template_cloud) { vendor { "google" } }
  factory(:template_microsoft, :class => "ManageIQ::Providers::Microsoft::InfraManager::Template", :parent => :template_infra) { vendor { "microsoft" } }
  factory(:template_redhat, :class => "ManageIQ::Providers::Redhat::InfraManager::Template", :parent => :template_infra) { vendor { "redhat" } }

  factory :template_vmware, :class => "ManageIQ::Providers::Vmware::InfraManager::Template", :parent => "template_infra" do
    location { |x| "[storage] #{x.name}/#{x.name}.vmtx" }
    vendor   { "vmware" }
  end

  factory :template_vmware_with_ref, :parent => :template_vmware do
    sequence(:ems_ref) { |n| "vm-#{seq_padded_for_sorting(n)}" }
    ems_ref_type       { "VirtualMachine" }
  end

  factory :template_vmware_cloud,
          :class  => "ManageIQ::Providers::Vmware::CloudManager::Template",
          :parent => :template_cloud do
    vendor { "vmware" }
  end

  factory :vm_amazon, :class => "ManageIQ::Providers::Amazon::CloudManager::Vm", :parent => :vm_cloud do
    location { |x| "#{x.name}.us-west-1.compute.amazonaws.com" }
    vendor   { "amazon" }

    trait :with_provider do
      after(:create) do |x|
        FactoryBot.create(:ems_amazon, :vms => [x])
      end
    end

    trait :powered_off do
      raw_power_state { "stopped" }
    end
  end

  factory :vm_azure, :class => "ManageIQ::Providers::Azure::CloudManager::Vm", :parent => :vm_cloud do
    location { "westus" }
    vendor   { "azure" }
    uid_ems  { "01234567890/test_resource_group/microsoft.resources/vm_1" }
    ems_ref  { "01234567890/test_resource_group/microsoft.resources/vm_1" }
    raw_power_state { "VM running" }
    name { "vm_1" }

    trait :with_provider do
      after(:create) do |x|
        FactoryBot.create(:ems_azure, :vms => [x])
      end
    end
  end

  factory :vm_google, :class => "ManageIQ::Providers::Google::CloudManager::Vm", :parent => :vm_cloud do
    vendor { "google" }

    trait :with_provider do
      after(:create) do |x|
        FactoryBot.create(:ems_google, :vms => [x])
      end
    end
  end

  factory :vm_microsoft, :class => "ManageIQ::Providers::Microsoft::InfraManager::Vm", :parent => :vm_infra do
    location        { |x| "#{x.name}/#{x.name}.xml" }
    vendor          { "microsoft" }
    raw_power_state { "Running" }
  end

  factory :vm_openstack, :class => "ManageIQ::Providers::Openstack::CloudManager::Vm", :parent => :vm_cloud do
    vendor          { "openstack" }
    raw_power_state { "ACTIVE" }
    sequence(:ems_ref) { |n| "some-uuid-#{seq_padded_for_sorting(n)}" }
    cloud_tenant { FactoryBot.create(:cloud_tenant_openstack) }

    factory :vm_perf_openstack, :parent => :vm_openstack do
      ems_ref { "openstack-perf-vm" }
    end

    trait :with_provider do
      after(:create) do |x|
        FactoryBot.create(:ems_openstack, :vms => [x])
      end
    end
  end

  factory :vm_redhat, :class => "ManageIQ::Providers::Redhat::InfraManager::Vm", :parent => :vm_infra do
    vendor          { "redhat" }
    raw_power_state { "up" }
  end

  factory :vm_vmware, :class => "ManageIQ::Providers::Vmware::InfraManager::Vm", :parent => :vm_infra do
    location        { |x| "[storage] #{x.name}/#{x.name}.vmx" }
    vendor          { "vmware" }
    raw_power_state { "poweredOn" }
    ems_ref_type    { "VirtualMachine" }
  end

  factory :vm_with_ref, :parent => :vm_vmware do
    sequence(:ems_ref) { |n| "vm-#{seq_padded_for_sorting(n)}" }
  end

  # Factories for perf_capture, perf_process testing
  factory :vm_perf, :parent => :vm_vmware do
    name     { "MIQ-WEBSVR1" }
    location { "MIQ-WEBSVR1/MIQ-WEBSVR1.vmx" }
    ems_ref  { "vm-578855" }
  end

  factory :vm_vmware_cloud, :class => "ManageIQ::Providers::Vmware::CloudManager::Vm", :parent => :vm_cloud do
    vendor { "vmware" }
  end
end
