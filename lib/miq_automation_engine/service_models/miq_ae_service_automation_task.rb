module MiqAeMethodService
  class MiqAeServiceAutomationTask < MiqAeServiceMiqRequestTask
    expose :automation_request, :association => true

    def statemachine_task_status
      ar_method do
        if ['finished'].include?(@object.state)
          @object.status.to_s.downcase
        else
          'retry'
        end
      end
    end

  end
end
