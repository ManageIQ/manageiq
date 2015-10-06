FactoryGirl.define do
  factory :miq_report do
    sequence(:name) { |n| "Test Report #{seq_padded_for_sorting(n)}" }
    db              'Vm'
    title           'some title'
    rpt_type        'Default'
    template_type   'report'
    rpt_group       'Custom'
    association     :miq_group
  end

  factory :miq_report_with_results, :parent => :miq_report do
    miq_report_results { [FactoryGirl.create(:miq_report_result)] }
  end
end
