FactoryBot.define do
  factory :authentication do
    userid      { "testuser" }
    password    { "secret" }
    authtype    { "default" }
    status      { "Valid" }
  end

  factory :authentication_status_error, :parent => :authentication do
    status      { "Error" }
    authtype    { "bearer" }
  end

  factory :authentication_ipmi, :parent => :authentication do
    authtype    { "ipmi" }
  end

  factory :authentication_ws, :parent => :authentication do
    authtype    { "ws" }
  end

  factory :authentication_ssh_keypair, :parent => :authentication, :class => 'ManageIQ::Providers::Openstack::InfraManager::AuthKeyPair' do
    authtype    { "ssh_keypair" }
    userid      { "testuser" }
    password    { nil }
    auth_key    { 'private_key_content' }
  end

  factory :authentication_ssh_keypair_root, :parent => :authentication_ssh_keypair do
    userid      { "root" }
  end

  factory :authentication_ssh_keypair_without_key, :parent => :authentication_ssh_keypair do
    auth_key    { nil }
    status      { "SomeMockedStatus" }
  end

  factory :authentication_v2v, :parent => :authentication_ssh_keypair do
    authtype    { "v2v" }
  end

  factory :authentication_redhat_metric, :parent => :authentication do
    authtype { "metrics" }
  end

  factory :automation_manager_authentication,
          :parent => :authentication,
          :class  => "ManageIQ::Providers::AutomationManager::Authentication"

  factory :embedded_automation_manager_authentication,
          :parent => :authentication,
          :class  => "ManageIQ::Providers::EmbeddedAutomationManager::Authentication"

  factory :ansible_credential,
          :parent => :automation_manager_authentication,
          :class  => "ManageIQ::Providers::AnsibleTower::AutomationManager::Credential"

  factory :ansible_cloud_credential,
          :parent => :ansible_credential,
          :class  => "ManageIQ::Providers::AnsibleTower::AutomationManager::CloudCredential"

  factory :ansible_machine_credential,
          :parent => :ansible_credential,
          :class  => "ManageIQ::Providers::AnsibleTower::AutomationManager::MachineCredential"

  factory :ansible_vault_credential,
          :parent => :ansible_credential,
          :class  => "ManageIQ::Providers::AnsibleTower::AutomationManager::VaultCredential"

  factory :ansible_network_credential,
          :parent => :ansible_credential,
          :class  => "ManageIQ::Providers::AnsibleTower::AutomationManager::NetworkCredential"

  factory :ansible_scm_credential,
          :parent => :ansible_credential,
          :class  => "ManageIQ::Providers::AnsibleTower::AutomationManager::ScmCredential"

  factory :embedded_ansible_credential,
          :parent => :embedded_automation_manager_authentication,
          :class  => "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Credential"

  factory :embedded_ansible_amazon_credential,
          :parent => :embedded_ansible_credential,
          :class  => "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::AmazonCredential"

  factory :embedded_ansible_azure_credential,
          :parent => :embedded_ansible_credential,
          :class  => "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::AzureCredential"

  factory :embedded_ansible_google_credential,
          :parent => :embedded_ansible_credential,
          :class  => "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::GoogleCredential"

  factory :embedded_ansible_machine_credential,
          :parent => :embedded_ansible_credential,
          :class  => "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::MachineCredential"

  factory :embedded_ansible_vault_credential,
          :parent => :embedded_ansible_credential,
          :class  => "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::VaultCredential"

  factory :embedded_ansible_cloud_credential,
          :parent => :embedded_ansible_credential,
          :class  => "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::CloudCredential"

  factory :embedded_ansible_openstack_credential,
          :parent => :embedded_ansible_credential,
          :class  => "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::OpenstackCredential"

  factory :embedded_ansible_rhv_credential,
          :parent => :embedded_ansible_credential,
          :class  => "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::RhvCredential"

  factory :embedded_ansible_scm_credential,
          :parent => :embedded_ansible_credential,
          :class  => "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ScmCredential"

  factory :embedded_ansible_vmware_credential,
          :parent => :embedded_ansible_credential,
          :class  => "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::VmwareCredential"

  factory :embedded_ansible_network_credential,
          :parent => :embedded_ansible_credential,
          :class  => "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::NetworkCredential"

  factory :auth_key_pair_cloud,     :class => "ManageIQ::Providers::CloudManager::AuthKeyPair"
  factory :auth_key_pair_amazon,    :class => "ManageIQ::Providers::Amazon::CloudManager::AuthKeyPair"
  factory :auth_key_pair_openstack, :class => "ManageIQ::Providers::Openstack::CloudManager::AuthKeyPair"
end
