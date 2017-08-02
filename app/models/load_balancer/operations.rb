module LoadBalancer::Operations
  extend ActiveSupport::Concern

  def update_load_balancer(options={})
    raw_update_load_balancer(options)
  end

  def raw_update_load_balancer(_options={})
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def delete_load_balancer
    raw_delete_load_balancer
  end

  def raw_delete_load_balancer
    raise NotImplementedError, _("must be implemented in a subclass")
  end
end
