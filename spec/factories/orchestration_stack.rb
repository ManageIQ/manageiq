FactoryBot.define do
  factory :orchestration_stack do
    ems_ref { "1" }
  end

  factory :orchestration_stack_cloud, :parent => :orchestration_stack, :class => "ManageIQ::Providers::CloudManager::OrchestrationStack"

  factory :orchestration_stack_cloud_with_template, :parent => :orchestration_stack, :class => "ManageIQ::Providers::CloudManager::OrchestrationStack" do
    orchestration_template { FactoryBot.create(:orchestration_template) }
  end

  factory :orchestration_stack_amazon, :parent => :orchestration_stack, :class => "ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack"

  factory :orchestration_stack_azure, :parent => :orchestration_stack, :class => "ManageIQ::Providers::Azure::CloudManager::OrchestrationStack"

  factory :orchestration_stack_openstack, :parent => :orchestration_stack, :class => "ManageIQ::Providers::Openstack::CloudManager::OrchestrationStack"

  factory :orchestration_stack_openstack_infra,
          :parent => :orchestration_stack,
          :class  => "ManageIQ::Providers::Openstack::InfraManager::OrchestrationStack" do
    after :create do |x|
      x.parameters << FactoryBot.create(:orchestration_stack_parameter_openstack_infra_compute)
      x.parameters << FactoryBot.create(:orchestration_stack_parameter_openstack_infra_controller)
      x.resources << FactoryBot.create(:orchestration_stack_resource_openstack_infra_compute)
      x.resources << FactoryBot.create(:orchestration_stack_resource_openstack_infra_compute_parent)
    end
  end

  factory :orchestration_stack_openstack_infra_nested,
          :parent => :orchestration_stack,
          :class  => "ManageIQ::Providers::Openstack::InfraManager::OrchestrationStack" do
  end

  factory :orchestration_stack_parameter_openstack_infra, :class => "OrchestrationStackParameter"

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

  factory :orchestration_stack_resource, :class => "OrchestrationStackResource"

  factory :orchestration_stack_resource_openstack_infra, :class => "OrchestrationStackResource"

  factory :orchestration_stack_output, :class => "OrchestrationStackOutput"

  factory :orchestration_stack_resource_openstack_infra_compute,
          :parent => :orchestration_stack_resource_openstack_infra do
    after :create do |x|
      x.physical_resource = "openstack-perf-host-nova-instance"
      x.stack = FactoryBot.create(:orchestration_stack_openstack_infra_nested)
    end
  end

  factory :orchestration_stack_resource_openstack_infra_compute_parent,
          :parent => :orchestration_stack_resource_openstack_infra do
    after :create do |x|
      x.physical_resource = "1"
      x.logical_resource = "1"
    end
  end

  factory :ansible_tower_job, :class => "ManageIQ::Providers::AnsibleTower::AutomationManager::Job"

  factory :ansible_tower_workflow_job, :class => "ManageIQ::Providers::AnsibleTower::AutomationManager::WorkflowJob"

  factory :embedded_ansible_job, :class => "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job"

  factory :orchestration_stack_vmware_cloud, :parent => :orchestration_stack, :class => "ManageIQ::Providers::Vmware::CloudManager::OrchestrationStack"

  factory :orchestration_stack_container, :parent => :orchestration_stack, :class => "ManageIQ::Providers::ContainerManager::OrchestrationStack"
end
