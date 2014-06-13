FactoryGirl.define do
  factory :miq_report do
    sequence(:name) { |n| "Test Report #{n}" }
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
end
