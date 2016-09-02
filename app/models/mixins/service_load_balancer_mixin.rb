module ServiceLoadBalancerMixin
  extend ActiveSupport::Concern

  included do
    has_many :load_balancer_managers, :through => :service_resources, :source => :resource, :source_type => 'ExtManagementSystem'
    has_many :load_balancers, :through => :service_resources, :source => :resource, :source_type => 'LoadBalancer'
    private :load_balancer_managers, :load_balancer_managers=
    private :load_balancers, :load_balancers=
  end

  def load_balancer_manager
    load_balancer_managers.take
  end

  def load_balancer_manager=(manager)
    self.load_balancer_managers = [manager].compact
  end

  def load_balancer
    load_balancers.take
  end
end
