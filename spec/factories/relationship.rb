FactoryBot.define do
  factory :relationship do
    trait :membership do
      relationship { 'membership' }
    end
  end

  factory :relationship_vm_vmware, :parent => :relationship do
    resource_type  { "VmOrTemplate" }
  end

  factory :relationship_host_vmware, :parent => :relationship do
    resource_type  { "Host" }
  end

  factory :relationship_storage_vmware, :parent => :relationship do
    resource_type  { "Storage" }
  end

  factory :relationship_miq_widget_set, :parent => :relationship do
    resource_type { 'MiqWidgetSet' }
  end

  factory :relationship_miq_widget, :parent => :relationship do
    resource_type { 'MiqWidget' }
  end

  factory :relationship_miq_widget_set_with_membership, :parent => :relationship_miq_widget_set,
                                                        :traits => [:membership]
  factory :relationship_miq_widget_with_membership, :parent => :relationship_miq_widget, :traits => [:membership]
end
