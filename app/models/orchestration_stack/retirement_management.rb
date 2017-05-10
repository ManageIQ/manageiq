class OrchestrationStack
  module RetirementManagement
    extend ActiveSupport::Concern
    include RetirementMixin

    module ClassMethods
      def retirement_check
        ems_ids = MiqServer.my_server.zone.ext_management_systems.pluck(:id)
        table   = OrchestrationStack.arel_table
        stacks  = OrchestrationStack.where(table[:retires_on].not_eq(nil)
          .and(table[:ems_id].in(ems_ids)))
        stacks.each(&:retirement_check)
      end
    end
  end
end
