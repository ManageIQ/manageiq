module MiqAeMethodService
  class MiqAeServiceServiceLoadBalancer < MiqAeServiceService
    require_relative "mixins/miq_ae_service_service_load_balancer_mixin"
    include MiqAeServiceServiceLoadBalancerMixin

    expose :load_balancer_name
    expose :load_balancer_name=
    expose :load_balancer_options
    expose :load_balancer_options=
    expose :update_options
    expose :update_options=
    expose :load_balancer_status
    expose :deploy_load_balancer
    expose :update_load_balancer
    expose :load_balancer
    expose :build_load_balancer_options_from_dialog
  end
end
