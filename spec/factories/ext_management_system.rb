FactoryGirl.define do
  factory :ext_management_system do
    sequence(:name)      { |n| "ems_#{seq_padded_for_sorting(n)}" }
    sequence(:hostname)  { |n| "ems_#{seq_padded_for_sorting(n)}" }
    sequence(:ipaddress) { |n| ip_from_seq(n) }
    guid                 { MiqUUID.new_guid }
    zone                 { Zone.first || FactoryGirl.create(:zone) }
  end

  # Intermediate classes

  factory :ems_infra,
          :aliases => ["manageiq/providers/infra_manager"],
          :class   => "ManageIQ::Providers::InfraManager",
          :parent  => :ext_management_system do
  end

  factory :ems_physical_infra,
          :aliases => ["manageiq/providers/physical_infra_manager"],
          :class   => "ManageIQ::Providers::PhysicalInfraManager",
          :parent  => :ext_management_system do
  end

  factory :ems_cloud,
          :aliases => ["manageiq/providers/cloud_manager"],
          :class   => "ManageIQ::Providers::CloudManager",
          :parent  => :ext_management_system do
  end

  factory :ems_network,
          :aliases => ["manageiq/providers/network_manager"],
          :class   => "ManageIQ::Providers::NetworkManager",
          :parent  => :ext_management_system do
  end

  factory :ems_storage,
          :aliases => ["manageiq/providers/storage_manager"],
          :class   => "ManageIQ::Providers::StorageManager",
          :parent  => :ext_management_system do
  end

  factory :ems_cinder,
          :aliases => ["manageiq/providers/storage_manager/cinder_manager"],
          :class   => "ManageIQ::Providers::StorageManager::CinderManager",
          :parent  => :ext_management_system do
  end

  factory :ems_swift,
          :aliases => ["manageiq/providers/storage_manager/swift_manager"],
          :class   => "ManageIQ::Providers::StorageManager::SwiftManager",
          :parent  => :ext_management_system do
  end

  factory :ems_container,
          :aliases => ["manageiq/providers/container_manager"],
          :class   => "ManageIQ::Providers::ContainerManager",
          :parent  => :ext_management_system do
  end

  factory :ems_middleware,
          :aliases => ["manageiq/providers/middleware_manager"],
          :class   => "ManageIQ::Providers::MiddlewareManager",
          :parent  => :ext_management_system do
  end

  factory :configuration_manager,
          :aliases => ["manageiq/providers/configuration_manager"],
          :class   => "ManageIQ::Providers::ConfigurationManager",
          :parent  => :ext_management_system do
  end

  factory :provisioning_manager,
          :aliases => ["manageiq/providers/provisioning_manager"],
          :class   => "ManageIQ::Providers::ProvisioningManager",
          :parent  => :ext_management_system do
  end

  # Leaf classes for ems_infra

  factory :ems_vmware,
          :aliases => ["manageiq/providers/vmware/infra_manager"],
          :class   => "ManageIQ::Providers::Vmware::InfraManager",
          :parent  => :ems_infra do
  end

  factory :ems_vmware_with_authentication,
          :parent => :ems_vmware do
    after(:create) do |x|
      x.authentications << FactoryGirl.create(:authentication)
    end
  end

  factory :ems_microsoft,
          :aliases => ["manageiq/providers/microsoft/infra_manager"],
          :class   => "ManageIQ::Providers::Microsoft::InfraManager",
          :parent  => :ems_infra do
  end

  factory :ems_microsoft_with_authentication,
          :parent => :ems_microsoft do
    after(:create) do |x|
      x.authentications << FactoryGirl.create(:authentication)
    end
  end

  factory :ems_redhat,
          :aliases => ["manageiq/providers/redhat/infra_manager"],
          :class   => "ManageIQ::Providers::Redhat::InfraManager",
          :parent  => :ems_infra do
  end

  factory :ems_redhat_with_authentication,
          :parent => :ems_redhat do
    after(:create) do |x|
      x.authentications << FactoryGirl.create(:authentication)
    end
  end

  factory :ems_redhat_with_metrics_authentication,
          :parent => :ems_redhat do
    after(:create) do |x|
      x.authentications << FactoryGirl.create(:authentication_redhat_metric)
    end
  end

  factory :ems_openstack_infra,
          :aliases => ["manageiq/providers/openstack/infra_manager"],
          :class   => "ManageIQ::Providers::Openstack::InfraManager",
          :parent  => :ems_infra do
  end

  factory :ems_openstack_infra_with_stack,
          :parent => :ems_openstack_infra do
    after :create do |x|
      x.orchestration_stacks << FactoryGirl.create(:orchestration_stack_openstack_infra)
      4.times { x.hosts << FactoryGirl.create(:host_openstack_infra) }
    end
  end

  factory :ems_openstack_infra_with_stack_and_compute_nodes,
          :parent => :ems_openstack_infra do
    after :create do |x|
      x.orchestration_stacks << FactoryGirl.create(:orchestration_stack_openstack_infra)
      x.hosts += [FactoryGirl.create(:host_openstack_infra_compute),
                  FactoryGirl.create(:host_openstack_infra_compute_maintenance)]
    end
  end

  factory :ems_openstack_infra_with_authentication,
          :parent => :ems_openstack_infra do
    after :create do |x|
      x.authentications << FactoryGirl.create(:authentication)
      x.authentications << FactoryGirl.create(:authentication, :authtype => "amqp")
    end
  end

  factory :ems_vmware_cloud,
          :aliases => ["manageiq/providers/vmware/cloud_manager"],
          :class   => "ManageIQ::Providers::Vmware::CloudManager",
          :parent  => :ems_cloud do
  end

  factory :ems_vmware_cloud_network,
          :aliases => ["manageiq/providers/vmware/network_manager"],
          :class   => "ManageIQ::Providers::Vmware::NetworkManager",
          :parent  => :ems_cloud do
  end

  # Leaf classes for ems_cloud

  factory :ems_amazon,
          :aliases => ["manageiq/providers/amazon/cloud_manager"],
          :class   => "ManageIQ::Providers::Amazon::CloudManager",
          :parent  => :ems_cloud do
    provider_region "us-east-1"
  end

  factory :ems_amazon_network,
          :aliases => ["manageiq/providers/amazon/network_manager"],
          :class   => "ManageIQ::Providers::Amazon::NetworkManager",
          :parent  => :ems_network do
    provider_region "us-east-1"
  end

  factory :ems_amazon_with_authentication,
          :parent => :ems_amazon do
    after(:create) do |x|
      x.authentications << FactoryGirl.create(:authentication)
    end
  end

  factory :ems_amazon_with_cloud_networks,
          :parent => :ems_amazon do
    after(:create) do |x|
      2.times { x.cloud_networks << FactoryGirl.create(:cloud_network_amazon) }
    end
  end

  factory :ems_azure,
          :aliases => ["manageiq/providers/azure/cloud_manager"],
          :class   => "ManageIQ::Providers::Azure::CloudManager",
          :parent  => :ems_cloud do
  end

  factory :ems_azure_network,
          :aliases => ["manageiq/providers/azure/network_manager"],
          :class   => "ManageIQ::Providers::Azure::NetworkManager",
          :parent  => :ems_network do
  end

  factory :ems_azure_with_authentication,
          :parent => :ems_azure do
    azure_tenant_id "ABCDEFGHIJABCDEFGHIJ0123456789AB"
    subscription "0123456789ABCDEFGHIJABCDEFGHIJKL"
    after :create do |x|
      x.authentications << FactoryGirl.create(:authentication)
    end
  end

  factory :ems_openstack,
          :aliases => ["manageiq/providers/openstack/cloud_manager"],
          :class   => "ManageIQ::Providers::Openstack::CloudManager",
          :parent  => :ems_cloud do
  end

  factory :ems_openstack_with_authentication,
          :parent => :ems_openstack do
    after :create do |x|
      x.authentications << FactoryGirl.create(:authentication)
      x.authentications << FactoryGirl.create(:authentication, :authtype => "amqp")
    end
  end

  factory :ems_openstack_network,
          :aliases => ["manageiq/providers/openstack/network_manager"],
          :class   => "ManageIQ::Providers::Openstack::NetworkManager",
          :parent  => :ems_network do
  end

  factory :ems_nuage_network,
          :aliases => ["manageiq/providers/nuage/network_manager"],
          :class   => "ManageIQ::Providers::Nuage::NetworkManager",
          :parent  => :ems_network do
  end

  factory :ems_google,
          :aliases => ["manageiq/providers/google/cloud_manager"],
          :class   => "ManageIQ::Providers::Google::CloudManager",
          :parent  => :ems_cloud do
    provider_region "us-central1"
  end

  factory :ems_google_with_authentication,
          :parent => :ems_google do
    after(:create) do |x|
      x.authentications << FactoryGirl.create(:authentication)
    end
  end

  factory :ems_google_network,
          :aliases => ["manageiq/providers/google/network_manager"],
          :class   => "ManageIQ::Providers::Google::NetworkManager",
          :parent  => :ems_network do
    provider_region "us-central1"
  end

  # Leaf classes for ems_container

  factory :ems_kubernetes,
          :aliases => ["manageiq/providers/kubernetes/container_manager"],
          :class   => "ManageIQ::Providers::Kubernetes::ContainerManager",
          :parent  => :ems_container do
  end

  factory :ems_kubernetes_with_authentication_err,
          :parent => :ems_kubernetes do
    after :create do |x|
      x.authentications << FactoryGirl.create(:authentication_status_error)
    end
  end


  factory :ems_openshift,
          :aliases => ["manageiq/providers/openshift/container_manager"],
          :class   => "ManageIQ::Providers::Openshift::ContainerManager",
          :parent  => :ems_container do
  end

  factory :ems_openshift_enterprise,
          :aliases => ["manageiq/providers/openshift_enterprise/container_manager"],
          :class   => "ManageIQ::Providers::OpenshiftEnterprise::ContainerManager",
          :parent  => :ems_container do
  end

  # Leaf classes for configuration_manager

  factory :configuration_manager_foreman,
          :aliases => ["manageiq/providers/foreman/configuration_manager"],
          :class   => "ManageIQ::Providers::Foreman::ConfigurationManager",
          :parent  => :configuration_manager

  factory :configuration_manager_ansible_tower,
          :aliases => ["manageiq/providers/ansible_tower/configuration_manager"],
          :class   => "ManageIQ::Providers::AnsibleTower::ConfigurationManager",
          :parent  => :configuration_manager

  trait(:provider) do
    after(:build, &:create_provider)
  end

  trait(:configuration_script) do
    after(:create) do |x|
      type = (x.type.split("::")[0..2] + ["ConfigurationManager", "ConfigurationScript"]).join("::")
      x.configuration_scripts << FactoryGirl.create(:configuration_script, :type => type)
    end
  end

  # Leaf classes for provisioning_manager

  factory :provisioning_manager_foreman,
          :aliases => ["manageiq/providers/foreman/provisioning_manager"],
          :class   => "ManageIQ::Providers::Foreman::ProvisioningManager",
          :parent  => :provisioning_manager do
  end

  # Leaf classes for middleware_manager

  factory :ems_hawkular,
          :aliases => ["manageiq/providers/hawkular/middleware_manager"],
          :class   => "ManageIQ::Providers::Hawkular::MiddlewareManager",
          :parent  => :ems_middleware do
  end
end
