FactoryBot.define do
  factory :host do
    sequence(:name)     { |n| "host_#{seq_padded_for_sorting(n)}" }
    sequence(:hostname) { |n| "host-#{seq_padded_for_sorting(n)}" }
    vmm_vendor          { "vmware" }
    ipaddress           { "127.0.0.1" }
    user_assigned_os    { "linux_generic" }
    power_state         { "on" }
  end

  factory :host_with_ref, :parent => :host do
    sequence(:ems_ref) { |n| "host-#{seq_padded_for_sorting(n)}" }
  end

  factory :host_with_authentication, :parent => :host do
    after(:create) do |x|
      x.authentications = [FactoryBot.build(:authentication, :resource => x)]
    end
  end

  factory :host_vmware_esx_with_authentication, :parent => :host_vmware_esx do
    after(:create) do |x|
      x.authentications = [FactoryBot.build(:authentication, :resource => x)]
    end
  end

  factory :host_with_ipmi, :parent => :host do
    ipmi_address { "127.0.0.1" }
    mac_address  { "aa:bb:cc:dd:ee:ff" }
    after(:create) do |x|
      x.authentications = [FactoryBot.build(:authentication_ipmi, :resource => x)]
    end
  end

  # Type specific subclasses
  factory(:host_vmware,     :parent => :host,        :class => "ManageIQ::Providers::Vmware::InfraManager::Host") do
    ems_ref_type { "HostSystem" }
  end
  factory(:host_vmware_esx, :parent => :host_vmware, :class => "ManageIQ::Providers::Vmware::InfraManager::HostEsx") do
    ems_ref_type { "HostSystem" }
    vmm_product  { "ESX" }
  end

  factory :host_redhat, :parent => :host, :class => "ManageIQ::Providers::Redhat::InfraManager::Host" do
    sequence(:ems_ref) { |n| "host-#{seq_padded_for_sorting(n)}" }
    vmm_vendor { "redhat" }
  end

  factory :host_openstack_infra, :parent => :host, :class => "ManageIQ::Providers::Openstack::InfraManager::Host" do
    vmm_vendor   { "unknown" }
    ems_ref      { "openstack-perf-host" }
    uid_ems      { "openstack-perf-host-nova-instance" }
    association :ems_cluster, factory: :ems_cluster_openstack
  end

  factory :host_openstack_infra_compute, :parent => :host_openstack_infra,
                                         :class  => "ManageIQ::Providers::Openstack::InfraManager::Host" do
    name { "host0 (NovaCompute)" }
  end

  factory :host_openstack_infra_compute_maintenance, :parent => :host_openstack_infra,
                                                     :class  => "ManageIQ::Providers::Openstack::InfraManager::Host" do
    name        { "host1 (NovaCompute)" }
    maintenance { true }
  end

  factory :host_microsoft, :parent => :host, :class => "ManageIQ::Providers::Microsoft::InfraManager::Host" do
    vmm_vendor  { "microsoft" }
    vmm_product { "Hyper-V" }
  end

  trait :storage do
    transient do
      storage_count { 1 }
    end

    after :create do |h, evaluator|
      h.storages = create_list :storage, evaluator.storage_count
    end
  end

  trait :storage_redhat do
    transient do
      storage_count { 1 }
    end

    after :create do |h, evaluator|
      h.storages = create_list :storage_redhat, evaluator.storage_count
    end
  end
end
