FactoryGirl.define do
  factory :repository do
    sequence(:name)     { |n| "repo_#{seq_padded_for_sorting(n)}" }
    relative_path       "//VMFS/blah"
  end
end
