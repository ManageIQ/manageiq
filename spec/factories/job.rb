FactoryBot.define do
  factory :job do
    sequence(:name) { |n| "job_#{seq_padded_for_sorting(n)}" }
  end

  factory :infra_conversion_job, :class => 'InfraConversionJob', :parent => :job
end
