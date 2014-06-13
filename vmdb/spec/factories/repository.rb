FactoryGirl.define do
  factory :repository do
    sequence(:name)     { |n| "repo_#{n}" }
    relative_path       "//VMFS/blah"
  end
end
