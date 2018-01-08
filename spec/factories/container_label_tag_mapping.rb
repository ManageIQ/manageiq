FactoryGirl.define do
  factory :container_label_tag_mapping do
    label_name 'name'

    trait :only_nodes do
      labeled_resource_type 'ContainerNode'
    end
  end

  # Mapping for <All> entities, as created in UI.
  factory :tag_mapping_with_category, :parent => :container_label_tag_mapping do
    transient do
      category_name { "kubernetes::" + Classification.sanitize_name(label_name.tr("/", ":")) }
      category_description { "Mapped #{label_name}" }
    end

    tag do
      category = FactoryGirl.create(:classification,
                                    :name         => category_name,
                                    :description  => category_description,
                                    :single_value => true,
                                    :read_only    => true)
      category.tag
    end
  end
end
