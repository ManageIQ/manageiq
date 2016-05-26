FactoryGirl.define do
  factory :miq_report_result do
  end

  factory :miq_chargeback_report_result, :parent => :miq_report_result do
    sequence(:name) { |n| "Test Report #{seq_padded_for_sorting(n)}" }
    db "ChargebackVm"
    report_source "Requested by user"
  end
end
