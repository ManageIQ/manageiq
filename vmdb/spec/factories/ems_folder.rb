FactoryGirl.define do
  factory :ems_folder do
    sequence(:name) { |n| "Test Folder #{n}" }
  end
end
