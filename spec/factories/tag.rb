FactoryGirl.define do
  factory :tag do
    sequence(:name) { |n| "/namespace/cat/tag_#{seq_padded_for_sorting(n)}" }
  end

  factory :managed_kubernetes_tag, :parent => :tag do
    sequence(:name) { |n| "/managed/kubernetes:tag_#{seq_padded_for_sorting(n)}" }
  end
end
