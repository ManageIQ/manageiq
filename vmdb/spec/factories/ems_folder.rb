FactoryGirl.define do
  factory :ems_folder do
    sequence(:name) { |n| "Test Folder #{n}" }
  end

  factory :datacenter, :parent => :ems_folder do
    is_datacenter true
  end
end
