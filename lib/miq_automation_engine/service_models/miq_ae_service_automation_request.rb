module MiqAeMethodService
  class MiqAeServiceAutomationRequest < MiqAeServiceMiqRequest
    expose :automation_tasks, :association => true
  end
end
