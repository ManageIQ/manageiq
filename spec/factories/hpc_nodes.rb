FactoryBot.define do
  factory :hpc_node do
    sequence(:name)    { |n| "node_#{seq_padded_for_sorting(n)}" }
    sequence(:ems_ref) { |n| "node_ref_#{seq_padded_for_sorting(n)}" }
  end
end
