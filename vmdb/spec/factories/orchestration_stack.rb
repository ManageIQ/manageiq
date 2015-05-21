FactoryGirl.define do
  factory :orchestration_stack do
  end

  factory :orchestration_stack_openstack_infra, :class => "OrchestrationStackOpenstackInfra" do
    after :create do |x|
      x.parameters << FactoryGirl.create(:orchestration_stack_parameter_openstack_infra_compute)
      x.parameters << FactoryGirl.create(:orchestration_stack_parameter_openstack_infra_controller)
    end
  end

  factory :orchestration_stack_parameter_openstack_infra, :class => "OrchestrationStackParameter" do
  end

  factory :orchestration_stack_parameter_openstack_infra_compute, :parent => :orchestration_stack_parameter_openstack_infra do
    after :create do |x|
      x.name = "compute-1::count"
      x.value = "1"
    end
  end

  factory :orchestration_stack_parameter_openstack_infra_controller, :parent => :orchestration_stack_parameter_openstack_infra do
    after :create do |x|
      x.name = "controller-1::count"
      x.value = "1"
    end
  end

  factory :orchestration_stack_openstack_infra_osp7, :class => "OrchestrationStackOpenstackInfra" do
    after :create do |x|
      x.parameters << FactoryGirl.create(:orchestration_stack_parameter_openstack_infra_compute_osp7)
      x.parameters << FactoryGirl.create(:orchestration_stack_parameter_openstack_infra_controller_osp7)
    end
  end

  factory :orchestration_stack_parameter_openstack_infra_compute_osp7, :parent => :orchestration_stack_parameter_openstack_infra do
    after :create do |x|
      x.name = "ComputeCount"
      x.value = "1"
    end
  end

  factory :orchestration_stack_parameter_openstack_infra_controller_osp7, :parent => :orchestration_stack_parameter_openstack_infra do
    after :create do |x|
      x.name = "ControllerCount"
      x.value = "1"
    end
  end

end
