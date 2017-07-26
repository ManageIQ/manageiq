class RetirementManager
  def self.check
    ems_ids = MiqServer.my_server.zone.ext_management_system_ids
    [LoadBalancer, OrchestrationStack, Vm, Service].flat_map do |i|
      instances = not_retired_with_ems(i, ems_ids)
      instances.each(&:retirement_check)
    end
  end

  private_class_method def self.not_retired_with_ems(model, ems_ids)
    return model.not_scheduled_for_retirement unless model.column_names.include?('ems_id') # Service not assigned to ems_ids
    model.not_scheduled_for_retirement.where(:ems_id => ems_ids)
  end
end
