FactoryBot.define do
  factory :file_depot do
    name { "File Depot" }
    uri  { "nfs://somehost/export" }
  end

  factory(:file_depot_ftp, :class => "FileDepotFtp", :parent => :file_depot) { uri { "ftp://somehost/export" } }
  factory(:file_depot_swift, :class => "FileDepotSwift", :parent => :file_depot) { uri { "swift://swifthost/swiftbucket" } }
  factory :file_depot_ftp_with_authentication, :parent => :file_depot_ftp do
    after(:create) { |x| x.authentications << FactoryBot.create(:authentication) }
  end
  factory :file_depot_swift_with_authentication, :parent => :file_depot_swift do
    after(:create) { |x| x.authentications << FactoryBot.create(:authentication) }
  end
end
