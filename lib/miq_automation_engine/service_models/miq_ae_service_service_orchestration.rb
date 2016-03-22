module MiqAeMethodService
  class MiqAeServiceServiceOrchestration < MiqAeServiceService
    require_relative "mixins/miq_ae_service_service_orchestration_mixin"
    include MiqAeServiceServiceOrchestrationMixin

    expose :stack_name
    expose :stack_name=
    expose :stack_ems_ref
    expose :stack_options
    expose :stack_options=
    expose :update_options
    expose :update_options=
    expose :orchestration_stack_status
    expose :deploy_orchestration_stack
    expose :update_orchestration_stack
    expose :orchestration_stack
    expose :build_stack_options_from_dialog
    expose :post_provision_configure
  end
end
