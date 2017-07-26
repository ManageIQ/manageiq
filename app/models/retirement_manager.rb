class RetirementManager
  def self.check
    ems_ids = MiqServer.my_server.zone.ext_management_system_ids
    [LoadBalancer, OrchestrationStack, Vm, Service].each do |model|
      table = model.arel_table
      arel = table[:retires_on].not_eq(nil).or(table[:retired].not_eq(true))
      arel = arel.and(table[:ems_id].in(ems_ids)) if model.column_names.include?('ems_id') # Service not assigned to ems_ids
      model.where(arel).each(&:retirement_check)
    end
  end
end
