FactoryGirl.define do
  factory :vmdb_metric do
  end

  factory :vmdb_metric_hourly, :parent => :vmdb_metric do
    capture_interval_name "hourly"
  end
end
