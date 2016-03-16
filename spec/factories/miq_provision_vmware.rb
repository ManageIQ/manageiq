FactoryGirl.define do
  factory :miq_provision_vmware, :class => "ManageIQ::Providers::Vmware::InfraManager::Provision" do
    trait :clone_to_vm do
      request_type "clone_to_vm"
    end
  end

  factory :miq_provision_vmware_via_pxe, :parent => :miq_provision_vmware, :class => "ManageIQ::Providers::Vmware::InfraManager::ProvisionViaPxe"
end
