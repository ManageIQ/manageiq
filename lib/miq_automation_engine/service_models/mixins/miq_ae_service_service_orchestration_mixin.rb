module MiqAeServiceServiceOrchestrationMixin
  extend ActiveSupport::Concern
  included do
    expose :orchestration_template
    expose :orchestration_manager
  end

  def orchestration_template=(template)
    if template && !template.kind_of?(MiqAeMethodService::MiqAeServiceOrchestrationTemplate)
      raise ArgumentError, "template must be a MiqAeServiceOrchestrationTemplate or nil"
    end

    ar_method do
      @object.orchestration_template = template ? OrchestrationTemplate.where(:id => template.id).first : nil
      @object.save
    end
  end

  def orchestration_manager=(manager)
    if manager && !manager.kind_of?(MiqAeMethodService::MiqAeServiceExtManagementSystem)
      raise ArgumentError, "manager must be a MiqAeServiceExtManagementSystem or nil"
    end

    ar_method do
      @object.orchestration_manager = manager ? ExtManagementSystem.where(:id => manager.id).first : nil
      @object.save
    end
  end
end
