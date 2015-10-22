FactoryGirl.define do
  factory :chargeback_rate_detail_measure do
    step  "1024"
  end
  factory :chargeback_rate_detail_measure_bytes, :parent => :chargeback_rate_detail_measure do
    name "Bytes Units"
    units_display ["B","KB","MB","GB","TB"]
    units ["bytes","kilobytes","megabytes","gigabytes","terabytes"]
  end
end
