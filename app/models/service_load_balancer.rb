class ServiceLoadBalancer < Service
  include ServiceLoadBalancerMixin
  include ServiceOrchestrationOptionsMixin

  alias_method :load_balancer_options, :stack_options
  alias_method :load_balancer_options=, :stack_options=

  # read from DB or parse from dialog
  def load_balancer_name
    @load_balancer_name ||= get_option(:load_balancer_name) || OptionConverter.load_balancer_name(get_option(:dialog) || {})
  end

  # override existing load_balancer name (most likely from dialog)
  def load_balancer_name=(lbname)
    @load_balancer_name = lbname
    save_option(:load_balancer_name, lbname)
  end

  def load_balancer_status
    return "check_status_failed", "load_balancer has not been deployed" unless load_balancer

    'create_complete'
  rescue MiqException::MiqLoadBalancerNotExistError, MiqException::MiqLoadBalancerStatusError => err
    # naming convention requires status to end with "failed"
    ["check_status_failed", err.message]
  end

  def deploy_load_balancer
    @load_balancer = LoadBalancer.create_load_balancer(
      load_balancer_manager, load_balancer_name, load_balancer_options)
    add_resource(@load_balancer)
    @load_balancer
  ensure
    # create options may never be saved before unless they were overridden
    save_create_options
  end

  def update_load_balancer
    # use template from service_template, which may be different from existing template
    load_balancer.raw_update_load_balancer(update_options)
  end

  def load_balancer
    @load_balancer ||= service_resources.find { |sr| sr.resource.kind_of?(LoadBalancer) }.try(:resource)
  end

  def build_stack_create_options
    build_load_balancer_options_from_dialog(get_option(:dialog))
  end

  def build_load_balancer_options_from_dialog(dialog_options)
    converter = OptionConverter.get_converter(dialog_options || {}, load_balancer_manager.class)
    converter.load_balancer_create_options
  end

  def indirect_vms
    load_balancer.try(:indirect_vms) || []
  end

  def direct_vms
    load_balancer.try(:vms) || []
  end

  def all_vms
    load_balancer.try(:vms) || []
  end

  private

  def save_create_options
    options.merge!(:load_balancer_name => load_balancer_name,
                   :create_options     => load_balancer_options)
    save!
  end
end
