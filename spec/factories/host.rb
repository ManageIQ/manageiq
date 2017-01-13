FactoryGirl.define do
  factory :host do
    sequence(:name)     { |n| "host_#{seq_padded_for_sorting(n)}" }
    sequence(:hostname) { |n| "host_#{seq_padded_for_sorting(n)}" }
    vmm_vendor          "vmware"
    ipaddress           "127.0.0.1"
    user_assigned_os    "linux_generic"
    power_state         "on"
  end

  factory :host_with_ref, :parent => :host do
    sequence(:ems_ref)     { |n| "host-#{seq_padded_for_sorting(n)}" }
    sequence(:ems_ref_obj) { |n| VimString.new("host-#{seq_padded_for_sorting(n)}", "HostSystem", "ManagedObjectReference") }
  end

  factory :host_with_authentication, :parent => :host do
    after(:create) do |x|
      x.authentications = [FactoryGirl.build(:authentication, :resource => x)]
    end
  end

  factory :host_vmware_esx_with_authentication, :parent => :host_vmware_esx do
    after(:create) do |x|
      x.authentications = [FactoryGirl.build(:authentication, :resource => x)]
    end
  end

  # Factories for perf_capture_timer and perf_capture_gap testing
  factory :host_target_vmware, :parent => :host do
    after(:create) do |x|
      x.perf_capture_enabled = toggle_on_name_seq(x)
      2.times { x.vms << FactoryGirl.create(:vm_target_vmware, :ext_management_system => x.ext_management_system) }
    end
  end

  factory :host_with_ipmi, :parent => :host do
    ipmi_address "127.0.0.1"
    mac_address  "aa:bb:cc:dd:ee:ff"
    after(:create) do |x|
      x.authentications = [FactoryGirl.build(:authentication_ipmi, :resource => x)]
    end
  end

  # Type specific subclasses
  factory(:host_vmware,     :parent => :host,        :class => "ManageIQ::Providers::Vmware::InfraManager::Host")
  factory(:host_vmware_esx, :parent => :host_vmware, :class => "ManageIQ::Providers::Vmware::InfraManager::HostEsx") { vmm_product "ESX" }

  factory :host_redhat, :parent => :host, :class => "ManageIQ::Providers::Redhat::InfraManager::Host" do
    sequence(:ems_ref) { |n| "host-#{seq_padded_for_sorting(n)}" }
    vmm_vendor "redhat"
  end

  factory :host_openstack_infra, :parent => :host, :class => "ManageIQ::Providers::Openstack::InfraManager::Host" do
    vmm_vendor  "unknown"
    ems_ref     "openstack-perf-host"
    ems_ref_obj "openstack-perf-host-nova-instance"
    association :ems_cluster, factory: :ems_cluster_openstack
  end

  factory :host_openstack_infra_compute, :parent => :host_openstack_infra,
                                         :class  => "ManageIQ::Providers::Openstack::InfraManager::Host" do
    name "host0 (NovaCompute)"
  end

  factory :host_openstack_infra_compute_maintenance, :parent => :host_openstack_infra,
                                                     :class  => "ManageIQ::Providers::Openstack::InfraManager::Host" do
    name        "host1 (NovaCompute)"
    maintenance true
  end

  factory :host_microsoft, :parent => :host, :class => "ManageIQ::Providers::Microsoft::InfraManager::Host" do
    vmm_vendor  "microsoft"
    vmm_product "Hyper-V"
  end

  trait :storage do
    after(:create) { |h| h.storages << FactoryGirl.create(:storage) }
  end
end
