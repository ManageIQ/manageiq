FactoryGirl.define do
  factory :miq_request_task do
    status "Ok"
  end

  factory :miq_provision_task, :parent => :miq_request_task,   :class => "MiqProvisionTask"
  factory :miq_provision,      :parent => :miq_provision_task, :class => "MiqProvision"

  # Bare Metal
  factory :miq_host_provision, :parent => :miq_request_task, :class => "MiqHostProvision"

  # Infra
  factory :miq_provision_microsoft,      :parent => :miq_provision,        :class => "ManageIQ::Providers::Microsoft::InfraManager::Provision"
  factory :miq_provision_redhat,         :parent => :miq_provision,        :class => "ManageIQ::Providers::Redhat::InfraManager::Provision"
  factory :miq_provision_redhat_via_iso, :parent => :miq_provision_redhat, :class => "ManageIQ::Providers::Redhat::InfraManager::ProvisionViaIso"
  factory :miq_provision_redhat_via_pxe, :parent => :miq_provision_redhat, :class => "ManageIQ::Providers::Redhat::InfraManager::ProvisionViaPxe"
  factory :miq_provision_vmware,         :parent => :miq_provision,        :class => "ManageIQ::Providers::Vmware::InfraManager::Provision" do
    trait :clone_to_vm do
      request_type "clone_to_vm"
    end
  end
  factory :miq_provision_vmware_via_pxe, :parent => :miq_provision_vmware, :class => "ManageIQ::Providers::Vmware::InfraManager::ProvisionViaPxe"

  # Cloud
  factory :miq_provision_cloud,     :parent => :miq_provision,       :class => "ManageIQ::Providers::CloudManager::Provision"
  factory :miq_provision_amazon,    :parent => :miq_provision_cloud, :class => "ManageIQ::Providers::Amazon::CloudManager::Provision"
  factory :miq_provision_azure,     :parent => :miq_provision_cloud, :class => "ManageIQ::Providers::Azure::CloudManager::Provision"
  factory :miq_provision_google,    :parent => :miq_provision_cloud, :class => "ManageIQ::Providers::Google::CloudManager::Provision"
  factory :miq_provision_openstack, :parent => :miq_provision_cloud, :class => "ManageIQ::Providers::Openstack::CloudManager::Provision"

  # Automate
  factory :automation_task, :parent => :miq_request_task, :class => "AutomationTask"

  # Services
  factory :service_reconfigure_task,        :parent => :miq_request_task, :class => "ServiceReconfigureTask"
  factory :service_template_provision_task, :parent => :miq_request_task, :class => "ServiceTemplateProvisionTask" do
    state        'pending'
    request_type 'clone_to_service'
  end
end
