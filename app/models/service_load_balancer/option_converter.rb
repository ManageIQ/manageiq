class ServiceLoadBalancer
  # helper class to convert user dialog options to load_balancer options understood by each manager (provider)
  class OptionConverter
    attr_reader :dialog_options

    def initialize(dialog_options)
      @dialog_options = dialog_options
    end

    def self.load_balancer_name(dialog_options)
      dialog_options['dialog_load_balancer_name']
    end

    def self.manager(dialog_options)
      if dialog_options['dialog_load_balancer_manager']
        ExtManagementSystem.find(dialog_options['dialog_load_balancer_manager'])
      end
    end

    def self.tenant_name(dialog_options)
      dialog_options['dialog_tenant_name']
    end

    def self.cloud_subnets(dialog_options)
      dialog_options['dialog_cloud_subnets'].split(",").each_with_object([]) do |cloud_subnet_id, cloud_subnets|
        cloud_subnets << CloudSubnet.find(cloud_subnet_id).ems_ref
      end
    end

    def self.security_groups(dialog_options)
      dialog_options['dialog_security_groups'].split(",").each_with_object([]) do |security_group_id, security_groups|
        security_groups << SecurityGroup.find(security_group_id).ems_ref
      end
    end

    def self.vms(dialog_options)
      dialog_options['dialog_vms'].split(",").each_with_object([]) do |vm_id, vms|
        vms << {:instance_id => Vm.find(vm_id).ems_ref}
      end
    end

    def self.load_balancer_listeners(dialog_options)
      (0..20).each_with_object([]) do |index, listeners|
        listener = {
          :load_balancer_port => dialog_options["dialog_load_balancer_listeners_#{index}_load_balancer_port"],
          :instance_port      => dialog_options["dialog_load_balancer_listeners_#{index}_instance_port"],
          :protocol           => dialog_options["dialog_load_balancer_listeners_#{index}_load_balancer_protocol"],
          :instance_protocol  => dialog_options["dialog_load_balancer_listeners_#{index}_instance_protocol"]
        }
        break if listener.values.any?(&:blank?)
        listeners << listener
      end
    end

    def self.load_balancer_health_checks(dialog_options)
      {
        :target              => dialog_options["dialog_load_balancer_health_checks_target"],
        :interval            => dialog_options["dialog_load_balancer_health_checks_interval"],
        :timeout             => dialog_options["dialog_load_balancer_health_checks_timeout"],
        :unhealthy_threshold => dialog_options["dialog_load_balancer_health_checks_unhealthy_threshold"],
        :healthy_threshold   => dialog_options["dialog_load_balancer_health_checks_healthy_threshold"]
      }
    end

    def load_balancer_create_options
      raise NotImplementedError, "load_balancer_create_options must be implemented by a subclass"
    end

    # factory method to instantiate a provider dependent converter
    def self.get_converter(dialog_options, manager_class)
      manager_class::LoadBalancerServiceOptionConverter.new(dialog_options)
    end
  end
end
