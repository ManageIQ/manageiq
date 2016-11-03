FactoryGirl.define do
  factory :git_repository do
    sequence(:name) { |n| "git_repo_#{seq_padded_for_sorting(n)}" }
  end
end
