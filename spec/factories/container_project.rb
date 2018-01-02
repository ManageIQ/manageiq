FactoryGirl.define do
  factory :container_project do
    sequence(:name) { |n| "container_project_#{seq_padded_for_sorting(n)}" }
    association :ext_management_system, :factory => :ems_openshift
  end
end
