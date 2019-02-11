class RetirementManager
  def self.check
    ems_ids = MiqServer.my_server.zone.ext_management_system_ids
    [OrchestrationStack, Vm, Service].flat_map do |i|
      instances = not_retired_with_ems(i, ems_ids)
      instances.each(&:retirement_check)
    end
  end

  def self.not_retired_with_ems(model, ems_ids)
    return model.scheduled_to_retire unless model.column_names.include?('ems_id') # Service not assigned to ems_ids
    model.scheduled_to_retire.where(:ems_id => ems_ids)
  end
  private_class_method :not_retired_with_ems
end
