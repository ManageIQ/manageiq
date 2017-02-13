FactoryGirl.define do
  factory :miq_request do
    requester { create(:user) }

    factory :miq_host_provision_request,         :class => "MiqHostProvisionRequest"
    factory :service_reconfigure_request,        :class => "ServiceReconfigureRequest"
    factory :service_template_provision_request, :class => "ServiceTemplateProvisionRequest"
    factory :vm_migrate_request,                 :class => "VmMigrateRequest"
    factory :vm_reconfigure_request,             :class => "VmReconfigureRequest"
  end
end
