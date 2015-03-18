FactoryGirl.define do
  factory :miq_provision_vmware, :parent => :miq_provision_task_virt, :class => "MiqProvisionVmware"
end
