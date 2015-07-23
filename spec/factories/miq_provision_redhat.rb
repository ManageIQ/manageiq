FactoryGirl.define do
  factory :miq_provision_redhat, :class => "ManageIQ::Providers::Redhat::InfraManager::Provision" do
  end

  factory :miq_provision_redhat_via_iso, :parent => :miq_provision_redhat, :class => "ManageIQ::Providers::Redhat::InfraManager::ProvisionViaIso" do
  end

  factory :miq_provision_redhat_via_pxe, :parent => :miq_provision_redhat, :class => "ManageIQ::Providers::Redhat::InfraManager::ProvisionViaPxe" do
  end
end
