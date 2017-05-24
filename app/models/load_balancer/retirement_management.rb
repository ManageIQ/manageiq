class LoadBalancer
  module RetirementManagement
    extend ActiveSupport::Concern
    include RetirementMixin

    module ClassMethods
      def retirement_check
        ems_ids        = MiqServer.my_server.zone.ext_management_systems
        table          = LoadBalancer.arel_table
        load_balancers = LoadBalancer.where.not(:retires_on => nil).or(
                           LoadBalancer.where(:retired => true, :ems_id => ems_ids))
        load_balancers.each(&:retirement_check)
      end
    end
  end
end
