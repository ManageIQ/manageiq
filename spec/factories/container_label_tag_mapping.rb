FactoryGirl.define do
  factory :container_label_tag_mapping do
    label_name 'name'

    trait :node do
      labeled_resource_type 'ContainerNode'
    end
  end
end
