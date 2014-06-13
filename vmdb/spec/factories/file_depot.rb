FactoryGirl.define do
  factory :file_depot do
    sequence(:name) { |n| "File Depot #{n}" }
  end
end
