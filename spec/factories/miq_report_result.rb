FactoryBot.define do
  factory :miq_report_result

  factory :miq_chargeback_report_result, :parent => :miq_report_result do
    sequence(:name) { |n| "Test Chargeback Report Result #{seq_padded_for_sorting(n)}" }
    db { "ChargebackVm" }
    report_source { "Requested by user" }
  end
end
