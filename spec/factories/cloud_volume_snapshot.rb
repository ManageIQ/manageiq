FactoryGirl.define do
  factory :cloud_volume_snapshot do
    sequence(:name)    { |n| "cloud_volume_snapshot_#{seq_padded_for_sorting(n)}" }
    sequence(:ems_ref) { |n| "ems_ref_#{seq_padded_for_sorting(n)}" }
  end
end
