FactoryBot.define do
  factory :host do
    sequence(:name)     { |n| "host_#{seq_padded_for_sorting(n)}" }
    sequence(:hostname) { |n| "host-#{seq_padded_for_sorting(n)}" }
    vmm_vendor          { "vmware" }
    ipaddress           { "127.0.0.1" }
    user_assigned_os    { "linux_generic" }
    power_state         { "on" }

    transient do
      authtype { nil }
      storage_count { nil }
    end

    trait :with_ref do
      ems_ref_type { "HostSystem" }
      sequence(:ems_ref) { |n| "host-#{seq_padded_for_sorting(n)}" }
    end

    after :create do |host, ev|
      host.storages = create_list :storage, ev.storage_count if ev.storage_count
      Array(ev.authtype).each { |a| host.authentications << FactoryBot.create(:authentication, :authtype => a, :resource => host) } if ev.authtype
    end
  end

  factory :host_with_ref, :parent => :host, :traits => [:with_ref]

  factory :host_with_authentication, :parent => :host do
    authtype { "default" }
  end

  factory :host_vmware_esx_with_authentication, :parent => :host_vmware_esx do
    authtype { "default" }
  end

  factory :host_with_ipmi, :parent => :host do
    ipmi_address { "127.0.0.1" }
    mac_address  { "aa:bb:cc:dd:ee:ff" }
    authtype     { "ipmi" }
  end

  # Type specific subclasses
  factory(:host_vmware,     :parent => :host,        :class => "ManageIQ::Providers::Vmware::InfraManager::Host") do
    ems_ref_type { "HostSystem" }
  end
  factory(:host_vmware_esx, :parent => :host_vmware, :class => "ManageIQ::Providers::Vmware::InfraManager::HostEsx") do
    ems_ref_type { "HostSystem" }
    vmm_product  { "ESX" }
  end

  factory :host_redhat, :parent => :host, :class => "ManageIQ::Providers::Redhat::InfraManager::Host", :traits => [:with_ref] do
    vmm_vendor { "redhat" }
  end

  factory :host_ovirt, :parent => :host, :class => "ManageIQ::Providers::Ovirt::InfraManager::Host", :traits => [:with_ref] do
    vmm_vendor { "ovirt" }
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
end
