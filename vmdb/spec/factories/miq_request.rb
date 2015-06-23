FactoryGirl.define do
  factory :miq_request do
    factory :miq_host_provision_request,         :class => MiqHostProvisionRequest
    factory :service_template_provision_request, :class => ServiceTemplateProvisionRequest
    factory :vm_migrate_request,                 :class => VmMigrateRequest
  end
end
