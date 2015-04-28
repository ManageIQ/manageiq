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

  factory :miq_report_with_null_condition, :parent => :miq_report do
    conditions nil
  end

  factory :miq_report_wo_null_but_nil_condition, :parent => :miq_report  do
    conditions 'CRAP'
  end

  factory :miq_report_with_non_nil_condition, :parent => :miq_report  do
    conditions MiqExpression.new({"FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Month", "Last Month"]}})
  end

  factory :miq_report_with_results, :parent => :miq_report do
    miq_report_results { [FactoryGirl.create(:miq_report_result)] }
  end
end
