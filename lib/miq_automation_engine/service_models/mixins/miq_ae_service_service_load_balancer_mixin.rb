module MiqAeServiceServiceLoadBalancerMixin
  extend ActiveSupport::Concern
  included do
    expose :load_balancer_manager
  end

  def load_balancer_manager=(manager)
    if manager && !manager.kind_of?(MiqAeMethodService::MiqAeServiceExtManagementSystem)
      raise ArgumentError, "manager must be a MiqAeServiceExtManagementSystem or nil"
    end

    ar_method do
      @object.load_balancer_manager = manager ? ExtManagementSystem.where(:id => manager.id).first : nil
      @object.save
    end
  end
end
