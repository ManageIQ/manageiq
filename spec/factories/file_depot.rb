FactoryGirl.define do
  factory :file_depot do
    name "File Depot"
    uri  "nfs://somehost/export"
  end
end
