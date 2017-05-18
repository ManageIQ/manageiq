class LoadBalancer
  module RetirementManagement
    extend ActiveSupport::Concern
    include RetirementMixin

    module ClassMethods
      def retirement_check
        ems_ids        = MiqServer.my_server.zone.ext_management_systems.pluck(:id)
        table          = LoadBalancer.arel_table
        load_balancers = LoadBalancer.where(table[:retires_on].not_eq(nil)
                                              .or(table[:retired].eq(true))
                                              .and(table[:ems_id].in(ems_ids)))
        load_balancers.each(&:retirement_check)
      end
    end
  end
end
