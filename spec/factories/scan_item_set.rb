FactoryBot.define do
  factory :scan_item_set do
    sequence(:name) { |i| "scan_item_set#{i}" }
    description { 'ScanItemSet description' }
  end
end
