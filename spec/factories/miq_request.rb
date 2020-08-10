FactoryBot.define do
  factory :miq_request do
    requester { create(:user) }

    factory :automation_request, :class => "AutomationRequest" do
      request_type { "automation" }
    end

    factory :service_reconfigure_request,        :class => "ServiceReconfigureRequest"
    factory :service_retire_request,             :class => "ServiceRetireRequest"
    factory :orchestration_stack_retire_request, :class => "OrchestrationStackRetireRequest"
    factory :service_template_provision_request, :class => "ServiceTemplateProvisionRequest" do
      source { create(:service_template) }
    end
    factory :vm_migrate_request,                 :class => "VmMigrateRequest"
    factory :vm_reconfigure_request,             :class => "VmReconfigureRequest"
    factory :miq_provision_request,              :class => "MiqProvisionRequest" do
      source { create(:miq_template) }
    end
    factory :physical_server_provision_request,        :class => "PhysicalServerProvisionRequest"
    factory :physical_server_firmware_update_request,  :class => "PhysicalServerFirmwareUpdateRequest"

    factory :service_template_transformation_plan_request, :class => "ServiceTemplateTransformationPlanRequest" do
      source { create(:service_template_transformation_plan) }
    end

    trait :with_approval do
      transient do
        reason { "" }
      end

      after(:create) do |request, evaluator|
        request.miq_approvals << FactoryBot.create(:miq_approval, :reason => evaluator.reason)
      end
    end
  end
end
