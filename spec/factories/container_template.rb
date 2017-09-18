FactoryGirl.define do
  factory :container_template do
  end

  factory :openshift_template,
          :aliases => ['manageiq/providers/openshift/container_manager/container_template'],
          :class   => 'ManageIQ::Providers::Openshift::ContainerManager::ContainerTemplate',
          :parent  => :container_template do
  end
end
