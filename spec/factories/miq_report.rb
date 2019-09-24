FactoryBot.define do
  factory :miq_report do
    sequence(:name) { |n| "Test Report #{seq_padded_for_sorting(n)}" }
    db              { 'Vm' }
    title           { 'some title' }
    rpt_type        { 'Default' }
    template_type   { 'report' }
    rpt_group       { 'Custom' }
    association     :miq_group
  end

  factory :miq_report_filesystem, :parent => :miq_report do
    sequence(:name) { |n| "Files #{seq_padded_for_sorting(n)}" }
    db              { 'Filesystem' }
    title           { 'Files' }
    cols            { %w(name base_name file_version size contents_available permissions updated_on mtime) }
    col_order       { %w(name base_name file_version size contents_available permissions updated_on mtime) }
    headers         { %w(Name File\ Name File\ Version Size Contents\ Available Permissions Collected\ On Last\ Modified) }
    sortby          { ["name"] }
    order           { "Ascending" }
  end

  factory :miq_report_with_results, :parent => :miq_report do
    miq_report_results { [FactoryBot.create(:miq_report_result, :miq_group => miq_group)] }
  end

  factory :miq_report_chargeback, :parent => :miq_report do
    sequence(:name) { |n| "Test Report #{seq_padded_for_sorting(n)}" }
    db              { 'ChargebackVm' }
    title           { 'some title' }
    rpt_type        { 'Default' }
    template_type   { 'report' }
    rpt_group       { 'Custom' }
    association     :miq_group
  end

  factory :miq_report_chargeback_with_results, :parent => :miq_report do
    miq_report_results { [FactoryBot.create(:miq_chargeback_report_result)] }
    sequence(:name) { |n| "Test Report #{seq_padded_for_sorting(n)}" }
    db              { 'ChargebackVm' }
    title           { 'some title' }
    rpt_type        { 'Default' }
    template_type   { 'report' }
    rpt_group       { 'Custom' }
    association     :miq_group
  end
end
