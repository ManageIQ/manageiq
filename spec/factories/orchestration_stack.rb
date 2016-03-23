FactoryGirl.define do
  factory :orchestration_stack do
  end

  factory :orchestration_stack_cloud, :parent => :orchestration_stack, :class => "ManageIQ::Providers::CloudManager::OrchestrationStack" do
  end

  factory :orchestration_stack_amazon, :parent => :orchestration_stack, :class => "ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack" do
  end

  factory :orchestration_stack_azure, :parent => :orchestration_stack, :class => "ManageIQ::Providers::Azure::CloudManager::OrchestrationStack" do
  end

  factory :orchestration_stack_openstack, :parent => :orchestration_stack, :class => "ManageIQ::Providers::Openstack::CloudManager::OrchestrationStack" do
  end

  factory :orchestration_stack_openstack_infra, :class => "ManageIQ::Providers::Openstack::InfraManager::OrchestrationStack" do
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

  factory :ansible_tower_job, :class => "ManageIQ::Providers::AnsibleTower::ConfigurationManager::Job" do
  end
end
