FactoryGirl.define do
  factory :orchestration_stack do
    ems_ref "1"
  end

  factory :orchestration_stack_cloud, :parent => :orchestration_stack, :class => "ManageIQ::Providers::CloudManager::OrchestrationStack" do
  end

  factory :orchestration_stack_cloud_with_template, :parent => :orchestration_stack, :class => "ManageIQ::Providers::CloudManager::OrchestrationStack" do
    orchestration_template { FactoryGirl.create(:orchestration_template) }
  end

  factory :orchestration_stack_amazon, :parent => :orchestration_stack, :class => "ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack" do
  end

  factory :orchestration_stack_amazon_with_non_orderable_template, :parent => :orchestration_stack, :class => "ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack" do
    orchestration_template { FactoryGirl.create(:orchestration_template_cfn, :orderable => false) }
  end

  factory :orchestration_stack_azure, :parent => :orchestration_stack, :class => "ManageIQ::Providers::Azure::CloudManager::OrchestrationStack" do
  end

  factory :orchestration_stack_openstack, :parent => :orchestration_stack, :class => "ManageIQ::Providers::Openstack::CloudManager::OrchestrationStack" do
  end

  factory :orchestration_stack_openstack_infra,
          :parent => :orchestration_stack,
          :class  => "ManageIQ::Providers::Openstack::InfraManager::OrchestrationStack" do
    after :create do |x|
      x.parameters << FactoryGirl.create(:orchestration_stack_parameter_openstack_infra_compute)
      x.parameters << FactoryGirl.create(:orchestration_stack_parameter_openstack_infra_controller)
      x.resources << FactoryGirl.create(:orchestration_stack_resource_openstack_infra_compute)
      x.resources << FactoryGirl.create(:orchestration_stack_resource_openstack_infra_compute_parent)
    end
  end

  factory :orchestration_stack_openstack_infra_nested,
          :parent => :orchestration_stack,
          :class  => "ManageIQ::Providers::Openstack::InfraManager::OrchestrationStack" do
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

  factory :orchestration_stack_resource, :class => "OrchestrationStackResource" do
  end

  factory :orchestration_stack_resource_openstack_infra, :class => "OrchestrationStackResource" do
  end

  factory :orchestration_stack_output, :class => "OrchestrationStackOutput" do
  end

  factory :orchestration_stack_resource_openstack_infra_compute,
          :parent => :orchestration_stack_resource_openstack_infra do
    after :create do |x|
      x.physical_resource = "openstack-perf-host-nova-instance"
      x.stack = FactoryGirl.create(:orchestration_stack_openstack_infra_nested)
    end
  end

  factory :orchestration_stack_resource_openstack_infra_compute_parent,
          :parent => :orchestration_stack_resource_openstack_infra do
    after :create do |x|
      x.physical_resource = "1"
      x.logical_resource = "1"
    end
  end

  factory :ansible_tower_job, :class => "ManageIQ::Providers::AnsibleTower::ConfigurationManager::Job" do
  end

  factory :orchestration_stack_vmware_cloud, :parent => :orchestration_stack, :class => "ManageIQ::Providers::Vmware::CloudManager::OrchestrationStack" do
  end
end
