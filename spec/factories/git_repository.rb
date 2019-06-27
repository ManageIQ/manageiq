FactoryBot.define do
  factory :git_repository do
    sequence(:name) { |n| "git_repo_#{seq_padded_for_sorting(n)}" }
    url do
      require 'faker'
      "https://#{Faker::Internet.domain_name}/#{Faker::Internet.domain_word}/#{Faker::Internet.domain_word}.git"
    end
  end
end
