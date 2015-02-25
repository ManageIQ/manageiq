module MiqAeMethodService
  class MiqAeServiceServiceOrchestration < MiqAeServiceService
    expose :orchestration_template
    expose :orchestration_manager
    expose :stack_name
    expose :stack_name=
    expose :stack_options
    expose :stack_options=
    expose :orchestration_stack_status
    expose :deploy_orchestration_stack

    def orchestration_template=(template)
      ar_method do
        if template.nil?
          @object.orchestration_template = nil
        elsif template.kind_of?(MiqAeMethodService::MiqAeServiceOrchestrationTemplate)
          @object.orchestration_template = OrchestrationTemplate.find(template.id)
        else
          raise ArgumentError, "template must be a MiqAeServiceOrchestrationTemplate"
        end
        @object.save
      end
    end

    def orchestration_manager=(manager)
      ar_method do
        if manager.nil?
          @object.orchestration_manager = nil
        elsif manager.kind_of?(MiqAeMethodService::MiqAeServiceExtManagementSystem)
          @object.orchestration_manager = ExtManagementSystem.find(manager.id)
        else
          raise ArgumentError, "manager must be a MiqAeServiceExtManagementSystem"
        end
        @object.save
      end
    end
  end
end
