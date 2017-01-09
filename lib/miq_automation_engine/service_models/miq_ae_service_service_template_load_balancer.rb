module MiqAeMethodService
  class MiqAeServiceServiceTemplateLoadBalancer < MiqAeServiceServiceTemplate
    require_relative "mixins/miq_ae_service_service_load_balancer_mixin"
    include MiqAeServiceServiceLoadBalancerMixin
  end
end
