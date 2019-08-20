class RetirementManager
  def self.check
    ems_ids = MiqServer.my_server.zone.ext_management_system_ids
    [OrchestrationStack, Vm].flat_map do |i|
      instances = not_retired_with_ems(i, ems_ids)
      instances.each(&:retirement_check)
    end
  end

  def self.check_per_region
    Service.scheduled_to_retire.each(&:retirement_check)
  end

  def self.not_retired_with_ems(model, ems_ids)
    model.scheduled_to_retire.where(:ems_id => ems_ids)
  end
  private_class_method :not_retired_with_ems
end
