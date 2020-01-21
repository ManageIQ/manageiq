FactoryBot.define do
  factory :scan_item

  factory :scan_item_category_default, :parent => :scan_item do
    attributes  do
      {
        "item_type"  => "category",
        "definition" => {
          "content" => [{"target" => "default"}]
        }
      }
    end
  end

  factory :scan_item_category_test, :parent => :scan_item do
    attributes  do
      {
        "item_type"  => "category",
        "definition" => {
          "content" => [{"target" => "test"}]
        }
      }
    end
  end

  factory :scan_item_file, :parent => :scan_item do
    attributes  { {"item_type" => "file", "definition" => {}} }
  end
end
