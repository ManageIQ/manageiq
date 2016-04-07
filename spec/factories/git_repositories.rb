FactoryGirl.define do
  factory :git_repository do
    sequence(:name) { |n| "git_repo_#{seq_padded_for_sorting(n)}" }
  end

  factory :git_repository_with_authentication,
          :parent => :git_repository do
    after(:create) do |x|
      x.authentications << FactoryGirl.create(:authentication)
    end
  end
end
