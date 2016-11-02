FactoryGirl.define do
  factory :chargeback_rate_detail_measure do
    step  "1024"
    name "Bytes Units"
    units_display %w(B KB MB GB TB)
    units %w(bytes kilobytes megabytes gigabytes terabytes)
  end
end
