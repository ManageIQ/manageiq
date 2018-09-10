FactoryGirl.define do
  factory :ext_management_system do
    sequence(:name)      { |n| "ems_#{seq_padded_for_sorting(n)}" }
    sequence(:hostname)  { |n| "ems-#{seq_padded_for_sorting(n)}" }
    sequence(:ipaddress) { |n| ip_from_seq(n) }
    guid                 { MiqUUID.new_guid }
    zone                 { Zone.first || FactoryGirl.create(:zone) }
    storage_profiles     { [] }

    # Traits

    trait :with_clusters do
      transient do
        cluster_count 3
      end

      after :create do |ems, evaluator|
        create_list :ems_cluster, evaluator.cluster_count, :ext_management_system => ems
      end
    end

    trait :with_storages do
      transient do
        storage_count 3
      end

      after :create do |ems, evaluator|
        create_list :storage, evaluator.storage_count, :ext_management_system => ems
      end
    end
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

  factory :ems_datawarehouse,
          :aliases => ["manageiq/providers/datawarehouse_manager"],
          :class   => "ManageIQ::Providers::DatawarehouseManager",
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

  # Automation managers

  factory :automation_manager,
          :aliases => ["manageiq/providers/automation_manager"],
          :class   => "ManageIQ::Providers::AutomationManager",
          :parent  => :ext_management_system do
  end

  factory :external_automation_manager,
          :aliases => ["manageiq/providers/external_automation_manager"],
          :class   => "ManageIQ::Providers::ExternalAutomationManager",
          :parent  => :automation_manager do
  end

  factory :embedded_automation_manager,
          :aliases => ["manageiq/providers/embedded_automation_manager"],
          :class   => "ManageIQ::Providers::EmbeddedAutomationManager",
          :parent  => :automation_manager do
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

  factory :ems_redhat_v3,
          :parent => :ems_redhat do
    api_version '3.5'
  end

  factory :ems_redhat_v4,
          :parent => :ems_redhat do
    api_version '4.0'
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

  factory :ems_google_with_vcr_authentication, :parent => :ems_google, :traits => [:with_zone] do
    after(:create) do |ems|
      project         = Rails.application.secrets.google.try(:[], 'project') || 'GOOGLE_PROJECT'

      # If service account JSON is not available in secrets provide a dummy JSON with fake certificate
      service_account = Rails.application.secrets.google.try(:[], 'service_account') || <<-GOOGLE_SERVICE_ACCOUNT
      {
        "type": "service_account",
        "project_id": "GOOGLE_PROJECT",
        "private_key_id": "1111111111111111111111111111111111111111",
        "private_key": "-----BEGIN RSA PRIVATE KEY-----\\nMIIEowIBAAKCAQEApY2Hv2jiSyzDvowhxVlUVZtDAguKJB7/NE3MOBZ+k6ER3rEu\\n5hJNu1TxVPj1dXcTIyKX7X5ipmqVQPyrZHd6ec8RVPlzEWfCF3Yew0qJ/8dIVI6e\\n//5JheSzabeGKx8v89K0Tso4b7WYInomFNKs35LQHLOtF1L0P8z2S44/0K02wzeO\\n3YhFM3MEONX7LOaYERheX9vFmjBI3UoO2twSScKAVB4N+y4bQgyTKcUNDbYW0TOm\\n673YBfjPLbKomr5t1C+A/Jn/pCd4oQy+k3GtlQYjLsJ8BabbKZtuCCExOno64loJ\\ntIqlKFo4hyB3MAYFNBvSLvgzX2OI/3OVX7e//QIDAQABAoIBACXHwq7f1KSrNpCJ\\nkjtjQ2e14vjYgVH08PCSwIQcPg6at2VGshk3HB4gKGLn3bxMzEU8Y8eDDChGMoF+\\nJ+7phT2/D4mA082pDBYmkqamoA+K/uqtEYQCF+1CX99ETo4Qs/TEpPlGFNMJcgqM\\nLZya53CuJGgoaNvlxm+46owbjlykjLQOlOpwvf0HSFwsOlOPFPn1YbWtUMV2XJj4\\n4haCP7QwrZiqct4CQZ7zowmoQH/u0akhQylK5HpUJETzrVrSHYwvcvWmu+HAlx5l\\n4YWrunCxjc7eT6cOFig887FOSfAkO5bbNvDlduNn4FYKLS7z2tuZGAh8Bme4Gf8P\\n8XIKowECgYEA2sGyEV+z3f793u1qy9E1Q/6K8BeC62NekOVePcGcnVxGGYqiiaWn\\nemmqOBcyLSYrdBfqo/4zoZke7QmPKlCVg4Uv8g2VXx/wUbW7yE5pWiqn/vpT9zV0\\ndJWy56LQNUo2e2BBL9PaU1UU93RLem3vyPf1KxADXZ8Fu63YIGzFSI0CgYEAwbz/\\nagd9Th2RVJ1uxV/G0Wstce1wXQILrONbBivdgqXcxe8SBDk6xcwJ3JdGoiTDXjBM\\n1zOvFhZvPCg/Y3nkB9jf8ORO41UaCdZ8KpYlJhUxu04sZ43j/BIteRMNjnxhZix2\\n9pBNC6GVkiy89/IzpTR7w6UVTrzmbw2nf5iRkTECgYBTV0gH5nYYNXVy4PC3BdVN\\nOkSkg9CU7R6yBTCKRqDsMqNiR7b0ye+sa2U2SWAMY2ZarGHwaIAzKKrnk6S/ckQD\\n/1Hs3c/ylbBw8NPB1F2+xFGMisJChFMBt6aZKSY5pzRqfJlZJ1UeOmPqgpve4NNh\\ntVXqOgeOO29ruSeF8uqWYQKBgQCMga+TjD76akM+ZLczehTNSLe6yoMVUSh6iKE5\\nRpLt77C/9HTSj1bqoOH+E9BsQ9FU/B6ebKNsl3Sw4lemo34Xmtg+8rWr9cpenCmN\\nETt79R8OQtG9gJB5/gzwpDrOvbI90b2tcFYQO24ohz29bPC7veaMq6taYXGV1QdH\\naLUZ4QKBgE/0lK/uRiAxbdRu9bEdq8eZpTick6dmey4rBLnB5yg7vATUZnRf5yuF\\njUNlWziC5y4XsOpAuAUgRi8NqSUHRhmZ8ecjaoFo1xUVifW4knuw/9Ikq+2UyN/Z\\nBy0ccuzCmppA8QoeQ86xPd6u+vCn1o4OaG+uSW7j5/GKXrUinMMb\\n-----END RSA PRIVATE KEY-----\\n",
        "client_email": "11111111111-compute@developer.gserviceaccount.com",
        "client_id": "111111111111111111111"
      }
      GOOGLE_SERVICE_ACCOUNT

      ems.authentications << FactoryGirl.create(
        :authentication,
        :type     => "AuthToken",
        :auth_key => service_account,
        :userid   => "_"
      )
      ems.update_attributes(:project => project)
    end
  end

  factory :ems_google_with_project, :parent => :ems_google_with_authentication, :traits => [:with_zone] do
    project 'GOOGLE_PROJECT'
  end

  trait :with_zone do
    zone do
      _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
      zone
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

  # Leaf classes for configuration_manager

  factory :configuration_manager_foreman,
          :aliases => ["manageiq/providers/foreman/configuration_manager"],
          :class   => "ManageIQ::Providers::Foreman::ConfigurationManager",
          :parent  => :configuration_manager

  trait(:provider) do
    after(:build, &:create_provider)
  end

  trait(:configuration_script) do
    after(:create) do |x|
      type = (x.type.split("::")[0..2] + ["AutomationManager", "ConfigurationScript"]).join("::")
      x.configuration_scripts << FactoryGirl.create(:configuration_script, :type => type)
    end
  end

  # Leaf classes for automation_manager

  factory :automation_manager_ansible_tower,
          :aliases => ["manageiq/providers/ansible_tower/automation_manager"],
          :class   => "ManageIQ::Providers::AnsibleTower::AutomationManager",
          :parent  => :external_automation_manager

  factory :embedded_automation_manager_ansible,
          :aliases => ["manageiq/providers/embedded_ansible/automation_manager"],
          :class   => "ManageIQ::Providers::EmbeddedAnsible::AutomationManager",
          :parent  => :embedded_automation_manager

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

  # Leaf classes for datawarehouse_manager

  factory :ems_hawkular_datawarehouse,
          :aliases => ["manageiq/providers/hawkular/datawarehouse_manager"],
          :class   => "ManageIQ::Providers::Hawkular::DatawarehouseManager",
          :parent  => :ems_datawarehouse do
  end
end
