FactoryBot.define do
  factory :hpc_queue do
    sequence(:name)    { |n| "queue_#{seq_padded_for_sorting(n)}" }
    sequence(:ems_ref) { |n| "queue_ref_#{seq_padded_for_sorting(n)}" }
  end
end
