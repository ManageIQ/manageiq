FactoryBot.define do
  factory :git_repository do
    sequence(:name) { |n| "git_repo_#{seq_padded_for_sorting(n)}" }
    sequence(:url)  { |n| "https://host#{seq_padded_for_sorting(n)}.com/word/repo#{n}.git" }
  end
end
