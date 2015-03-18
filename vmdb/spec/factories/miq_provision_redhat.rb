FactoryGirl.define do
  factory :miq_provision_redhat, :parent => :miq_provision_task_virt, :class => "MiqProvisionRedhat"
  factory :miq_provision_redhat_via_iso, :parent => :miq_provision_redhat, :class => "MiqProvisionRedhatViaIso"
  factory :miq_provision_redhat_via_pxe, :parent => :miq_provision_redhat, :class => "MiqProvisionRedhatViaPxe"
end
