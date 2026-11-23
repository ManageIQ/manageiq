FactoryBot.define do
  factory :hpc_job do
    sequence(:name)    { |n| "job_#{seq_padded_for_sorting(n)}" }
    sequence(:ems_ref) { |n| "job_ref_#{seq_padded_for_sorting(n)}" }
  end
end
