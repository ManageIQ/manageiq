FactoryGirl.define do
  factory :ems_cluster do
    sequence(:name) { |n| "cluster_#{seq_padded_for_sorting(n)}" }
  end

  factory :cluster_target, :parent => :ems_cluster do
    after(:create) do |x|
      x.perf_capture_enabled = toggle_on_name_seq(x)
    end
  end
end
