# describe ReportFormatter::ChartCommon do
#
# We have to operate on the specific class although we are testing the common behavior.
# Otherwise expect_any_instance_of(described_class).to receive(:build_performance_chart_area).once.and_call_original
# leads to with:
#    SystemStackError:
#      stack level too deep
#    # ./lib/report_formatter/chart_common.rb:555:in `build_performance_chart'
#    # ./lib/report_formatter/chart_common.rb:57:in `call'

describe ManageIQ::Reporting::Formatter::C3 do
  include Spec::Support::ReportHelper

  before do
    allow(ManageIQ::Reporting::Charting).to receive(:backend).and_return(:c3)
    allow(ManageIQ::Reporting::Charting).to receive(:format).and_return(:c3)
  end
  context '#build_performance_chart_area' do
    it "builds a daily chart with all nils" do
      report = MiqReport.new(
        :db          => "VimPerformanceDaily",
        :cols        => cols = %w(timestamp cpu_usagemhz_rate_average min_cpu_usagemhz_rate_average max_cpu_usagemhz_rate_average trend_max_cpu_usagemhz_rate_average resource.cpu_usagemhz_rate_average_high_over_time_period resource.cpu_usagemhz_rate_average_low_over_time_period),
        :include     => {
          "resource" => {
            "columns" => %w(cpu_usagemhz_rate_average_high_over_time_period cpu_usagemhz_rate_average_low_over_time_period derived_memory_used_high_over_time_period derived_memory_used_low_over_time_period),
          }
        },
        :col_order   => cols,
        :headers     => ["Date/Time", "Avg Used", "Max Available", "Max Reserved", "Trend Max Used", "foo", "bar"],
        :order       => "ascending",
        :sortby      => "timestamp",
        :group       => "n",
        :graph       => {
          :type         => "Line",
          :columns      => %w(cpu_usagemhz_rate_average min_cpu_usagemhz_rate_average max_cpu_usagemhz_rate_average trend_max_cpu_usagemhz_rate_average resource.cpu_usagemhz_rate_average_high_over_time_period resource.cpu_usagemhz_rate_average_low_over_time_period),
          :legends      => nil,
          :max_col_size => nil
        },
        :dims        => nil,
        :col_formats => nil,
        :col_options => nil,
        :rpt_options => nil,
      )

      report.table = Ruport::Data::Table.new(
        :column_names => %w(timestamp cpu_usagemhz_rate_average min_cpu_usagemhz_rate_average max_cpu_usagemhz_rate_average trend_max_cpu_usagemhz_rate_average),
        :data         => [["Sun, 20 Mar 2016 00:00:00 UTC +00:00", 0.0, nil, nil, 0]]
      )

      expect_any_instance_of(described_class).to receive(:build_performance_chart_area).once.and_call_original
      render_report(report) { |e| e.options.graph_options[:chart_type] = :performance }
      expect(report.chart[:data]).to be
    end
  end
end
