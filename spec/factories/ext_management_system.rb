FactoryBot.define do
  factory :ext_management_system,
          :class   => "ManageIQ::Providers::Vmware::InfraManager" do
    # The provider has to be set before the hostname/ipaddress sequences as in some cases these attributes
    # might be delegated to the provider. As the attributes are being set based on the order in this file,
    # it is important to keep this line at the beginning of the factory.
    provider { nil }

    sequence(:name)      { |n| "ems_#{seq_padded_for_sorting(n)}" }
    sequence(:hostname)  { |n| "ems-#{seq_padded_for_sorting(n)}" }
    sequence(:ipaddress) { |n| ip_from_seq(n) }
    zone                 { FactoryBot.create(:zone) }
    storage_profiles     { [] }

    # authorizations

    transient do
      authtype { nil }
    end

    after(:create) do |ems, ev|
      Array(ev.authtype).each { |a| ems.authentications << FactoryBot.create(:authentication, :authtype => a) }
    end

    # Traits

    trait :with_clusters do
      transient do
        cluster_count { 3 }
      end

      after :create do |ems, evaluator|
        create_list :ems_cluster, evaluator.cluster_count, :ext_management_system => ems
      end
    end

    trait :with_storages do
      transient do
        storage_count { 3 }
      end

      after :create do |ems, evaluator|
        create_list :storage, evaluator.storage_count, :ext_management_system => ems
      end
    end

    trait :with_storages_redhat do
      transient do
        storage_count { 1 }
      end

      after :create do |ems, evaluator|
        ems.storages = create_list :storage_redhat, evaluator.storage_count, :ext_management_system => ems
      end
    end

    trait :with_authentication do
      authtype { "default" }
    end

    trait :with_unvalidated_authentication do
      after(:create) do |x|
        x.authentications << FactoryBot.create(:authentication, :status => nil)
      end
    end

    trait :with_invalid_authentication do
      after(:create) do |x|
        x.authentications << FactoryBot.create(:authentication, :status => "invalid")
      end
    end
  end

  # Intermediate classes
  # using leaf classes...
  factory :ems_infra,
          :aliases => ["manageiq/providers/infra_manager"],
          :class   => "ManageIQ::Providers::Vmware::InfraManager",
          :parent  => :ext_management_system

  factory :ems_physical_infra,
          :aliases => ["manageiq/providers/physical_infra_manager"],
          :class   => "ManageIQ::Providers::Redfish::PhysicalInfraManager",
          :parent  => :ext_management_system

  factory(:ems_cloud,
          :aliases => ["manageiq/providers/cloud_manager"],
          :class   => "ManageIQ::Providers::Amazon::CloudManager",
          :parent  => :ext_management_system) do
    provider_region { "us-east-1" }
  end

  factory :ems_network,
          :aliases => ["manageiq/providers/network_manager"],
          :class   => "ManageIQ::Providers::Openstack::NetworkManager",
          :parent  => :ext_management_system do
    parent_manager { FactoryBot.create(:ext_management_system) }
  end

  factory :ems_storage,
          :aliases => ["manageiq/providers/storage_manager"],
          :class   => "ManageIQ::Providers::StorageManager::SwiftManager",
          :parent  => :ext_management_system do
    parent_manager { FactoryBot.create(:ext_management_system) }
  end

  factory :ems_cinder,
          :aliases => ["manageiq/providers/storage_manager/cinder_manager"],
          :class   => "ManageIQ::Providers::StorageManager::CinderManager",
          :parent  => :ext_management_system do
    parent_manager { FactoryBot.create(:ext_management_system) }
  end

  factory :ems_autosde,
          :aliases => ["manageiq/providers/storage_manager/autosde_manager"],
          :class   => "ManageIQ::Providers::Autosde::StorageManager",
          :parent  => :ext_management_system do
    parent_manager { FactoryBot.create(:ext_management_system) }
  end

  factory :ems_swift,
          :aliases => ["manageiq/providers/storage_manager/swift_manager"],
          :class   => "ManageIQ::Providers::StorageManager::SwiftManager",
          :parent  => :ext_management_system do
    parent_manager { FactoryBot.create(:ext_management_system) }
  end

  factory :ems_container,
          :aliases => ["manageiq/providers/container_manager"],
          :class   => "ManageIQ::Providers::Openshift::ContainerManager",
          :parent  => :ext_management_system

  factory :configuration_manager,
          :aliases => ["manageiq/providers/configuration_manager"],
          :class   => "ManageIQ::Providers::Foreman::ConfigurationManager",
          :parent  => :ext_management_system do
    provider :factory => :provider_foreman
  end

  # Automation managers

  factory :automation_manager,
          :aliases => ["manageiq/providers/automation_manager"],
          :class   => "ManageIQ::Providers::AnsibleTower::AutomationManager",
          :parent  => :ext_management_system

  factory :provisioning_manager,
          :aliases => ["manageiq/providers/provisioning_manager"],
          :class   => "ManageIQ::Providers::Foreman::ProvisioningManager",
          :parent  => :ext_management_system do
    provider :factory => :provider_foreman
  end

  # Leaf classes for ems_infra

  factory :ems_vmware,
          :aliases => ["manageiq/providers/vmware/infra_manager"],
          :class   => "ManageIQ::Providers::Vmware::InfraManager",
          :parent  => :ems_infra

  factory :ems_vmware_with_authentication,
          :parent => :ems_vmware do
    authtype { "default" }
  end

  factory :ems_microsoft,
          :aliases => ["manageiq/providers/microsoft/infra_manager"],
          :class   => "ManageIQ::Providers::Microsoft::InfraManager",
          :parent  => :ems_infra

  factory :ems_microsoft_with_authentication,
          :parent => :ems_microsoft do
    authtype { "default" }
  end

  factory :ems_redhat,
          :aliases => ["manageiq/providers/redhat/infra_manager"],
          :class   => "ManageIQ::Providers::Redhat::InfraManager",
          :parent  => :ems_infra

  factory :ems_redhat_v3,
          :parent => :ems_redhat do
    api_version { '3.5' }
  end

  factory :ems_redhat_v4,
          :parent => :ems_redhat do
    api_version { '4.0' }
  end

  factory :ems_redhat_with_authentication,
          :parent => :ems_redhat do
    authtype { "default" }
  end

  trait :skip_validate do
    to_create { |instance| instance.save(:validate => false) }
  end

  factory :ems_redhat_with_authentication_with_ca,
          :parent => :ems_redhat do
    certificate_authority { "cert108" }
    authtype { "default" }
  end

  factory :ems_redhat_with_metrics_authentication,
          :parent => :ems_redhat do
    after(:create) do |x|
      x.authentications << FactoryBot.create(:authentication_redhat_metric)
    end
  end

  factory :ems_openstack_infra,
          :aliases => ["manageiq/providers/openstack/infra_manager"],
          :class   => "ManageIQ::Providers::Openstack::InfraManager",
          :parent  => :ems_infra

  factory :ems_openstack_infra_with_stack,
          :parent => :ems_openstack_infra do
    after :create do |x|
      x.orchestration_stacks << FactoryBot.create(:orchestration_stack_openstack_infra)
      4.times { x.hosts << FactoryBot.create(:host_openstack_infra) }
    end
  end

  factory :ems_openstack_infra_with_stack_and_compute_nodes,
          :parent => :ems_openstack_infra do
    after :create do |x|
      x.orchestration_stacks << FactoryBot.create(:orchestration_stack_openstack_infra)
      x.hosts += [FactoryBot.create(:host_openstack_infra_compute),
                  FactoryBot.create(:host_openstack_infra_compute_maintenance)]
    end
  end

  factory :ems_openstack_infra_with_authentication,
          :parent => :ems_openstack_infra do
    authtype { %w(default amqp) }
  end

  factory :ems_vmware_cloud,
          :aliases => ["manageiq/providers/vmware/cloud_manager"],
          :class   => "ManageIQ::Providers::Vmware::CloudManager",
          :parent  => :ems_cloud

  factory :ems_vmware_cloud_network,
          :aliases => ["manageiq/providers/vmware/network_manager"],
          :class   => "ManageIQ::Providers::Vmware::NetworkManager",
          :parent  => :ems_cloud do
    parent_manager { FactoryBot.create(:ext_management_system) }
  end

  # Leaf classes for ems_cloud

  factory :ems_amazon,
          :aliases => ["manageiq/providers/amazon/cloud_manager"],
          :class   => "ManageIQ::Providers::Amazon::CloudManager",
          :parent  => :ems_cloud do
    provider_region { "us-east-1" }
  end

  factory :ems_amazon_network,
          :aliases => ["manageiq/providers/amazon/network_manager"],
          :class   => "ManageIQ::Providers::Amazon::NetworkManager",
          :parent  => :ems_network do
    provider_region { "us-east-1" }
  end

  factory :ems_amazon_with_authentication,
          :parent => :ems_amazon do
    authtype { "default" }
  end

  factory :ems_amazon_with_cloud_networks,
          :parent => :ems_amazon do
    after(:create) do |x|
      2.times { x.cloud_networks << FactoryBot.create(:cloud_network_amazon) }
    end
  end

  factory :ems_azure,
          :aliases => ["manageiq/providers/azure/cloud_manager"],
          :class   => "ManageIQ::Providers::Azure::CloudManager",
          :parent  => :ems_cloud do
    provider_region { "eastus" }
  end

  factory :ems_azure_network,
          :aliases => ["manageiq/providers/azure/network_manager"],
          :class   => "ManageIQ::Providers::Azure::NetworkManager",
          :parent  => :ems_network do
    provider_region { "eastus" }
  end

  factory :ems_azure_with_authentication,
          :parent => :ems_azure do
    azure_tenant_id { "ABCDEFGHIJABCDEFGHIJ0123456789AB" }
    subscription { "0123456789ABCDEFGHIJABCDEFGHIJKL" }
    authtype { "default" }
  end

  factory :ems_openstack,
          :aliases => ["manageiq/providers/openstack/cloud_manager"],
          :class   => "ManageIQ::Providers::Openstack::CloudManager",
          :parent  => :ext_management_system

  factory :ems_openstack_with_authentication,
          :parent => :ems_openstack do
    authtype { %w(default amqp) }
  end

  factory :ems_openstack_network,
          :aliases => ["manageiq/providers/openstack/network_manager"],
          :class   => "ManageIQ::Providers::Openstack::NetworkManager",
          :parent  => :ems_network

  factory :ems_nuage_network,
          :aliases => ["manageiq/providers/nuage/network_manager"],
          :class   => "ManageIQ::Providers::Nuage::NetworkManager",
          :parent  => :ems_network


  factory :ems_nsxt_network,
          :aliases => ["manageiq/providers/nsxt/network_manager"],
          :class   => "ManageIQ::Providers::Nsxt::NetworkManager",
          :parent  => :ems_network

  factory :ems_google,
          :aliases => ["manageiq/providers/google/cloud_manager"],
          :class   => "ManageIQ::Providers::Google::CloudManager",
          :parent  => :ems_cloud

  factory :ems_google_with_authentication,
          :parent => :ems_google do
    authtype { "default" }
  end

  factory :ems_google_network,
          :aliases => ["manageiq/providers/google/network_manager"],
          :class   => "ManageIQ::Providers::Google::NetworkManager",
          :parent  => :ems_network

  # Leaf classes for ems_container

  factory :ems_kubernetes,
          :aliases => ["manageiq/providers/kubernetes/container_manager"],
          :class   => "ManageIQ::Providers::Kubernetes::ContainerManager",
          :parent  => :ems_container

  factory :ems_kubernetes_with_authentication_err,
          :parent => :ems_kubernetes do
    after :create do |x|
      x.authentications << FactoryBot.create(:authentication_status_error)
    end
  end

  factory :ems_openshift,
          :aliases => ["manageiq/providers/openshift/container_manager"],
          :class   => "ManageIQ::Providers::Openshift::ContainerManager",
          :parent  => :ems_container

  # Leaf classes for configuration_manager

  factory :configuration_manager_foreman,
          :aliases => ["manageiq/providers/foreman/configuration_manager"],
          :class   => "ManageIQ::Providers::Foreman::ConfigurationManager",
          :parent  => :configuration_manager do
    provider :factory => :provider_foreman
  end

  trait(:provider) do
    after(:build, &:create_provider)
  end

  trait(:configuration_script) do
    after(:create) do |x|
      type = (x.type.split("::")[0..2] + ["AutomationManager", "ConfigurationScript"]).join("::")
      x.configuration_scripts << FactoryBot.create(:configuration_script, :type => type)
    end
  end

  trait(:configuration_workflow) do
    after(:create) do |x|
      type = (x.type.split("::")[0..2] + %w(AutomationManager ConfigurationWorkflow)).join("::")
      x.configuration_scripts << FactoryBot.create(:configuration_workflow, :type => type)
    end
  end

  # Leaf classes for automation_manager

  factory :embedded_automation_manager_ansible,
          :aliases => ["manageiq/providers/embedded_ansible/automation_manager"],
          :class   => "ManageIQ::Providers::EmbeddedAnsible::AutomationManager",
          :parent  => :automation_manager

  # Leaf classes for provisioning_manager

  factory :provisioning_manager_foreman,
          :aliases => ["manageiq/providers/foreman/provisioning_manager"],
          :class   => "ManageIQ::Providers::Foreman::ProvisioningManager",
          :parent  => :provisioning_manager do
    provider :factory => :provider_foreman
  end
end
