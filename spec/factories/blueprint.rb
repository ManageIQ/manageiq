FactoryGirl.define do
  factory :blueprint do
    sequence(:name) { |n| "Blueprint #{n}" }
    ui_properties do
      {
        "service_catalog"      => { "id" => "id"},
        "service_dialog"       => { "id" =>"id"},
        "automate_entrypoints" => {
          "Reconfigure" => "x\/y/\/z",
          "Provision"   => "a\/b\/c"
        },
        "ChartDataModel"       => {
          "nodes" => [
            {
              "x"    => 102,
              "y"    => 100,
              "id"   => 10,
              "name" => "composite_generic"
            }
          ]}
      }
    end
  end
end
