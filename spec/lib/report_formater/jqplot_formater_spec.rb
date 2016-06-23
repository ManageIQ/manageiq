include ReportsSpecHelper

describe ReportFormatter::JqplotFormatter do
  before(:each) do
    allow(Charting).to receive(:backend).and_return(:jqplot)
    allow(Charting).to receive(:format).and_return(:jqplot)
  end
  context '#build_numeric_chart_grouped' do
    [true, false].each do |other|
      it "builds 2d numeric charts from summaries #{other ? 'with' : 'without'} 'other'" do
        report = numeric_charts_2d_from_summaries(other)

        expect_any_instance_of(described_class).to receive(:build_numeric_chart_grouped).once.and_call_original
        render_report(report)
        expect(report.chart[:data][0][0]).to eq(4.0)
        expect(report.chart[:options][:axes][:xaxis][:ticks][0]).to eq('blah')
        expect(report.chart[:data][0][-1]).to eq(4) if other
      end
    end
  end

  context '#build_numeric_chart_simple' do
    [true, false].each do |other|
      it "builds 2d numeric charts #{other ? 'with' : 'without'} 'other'" do
        report = numeric_chart_simple2(other)

        expect_any_instance_of(described_class).to receive(:build_numeric_chart_simple).once.and_call_original
        render_report(report)
        expect(report.chart[:data][0][0]).to eq(15)
        expect(report.chart[:options][:axes][:yaxis][:ticks][0]).to eq("bar")
        expect(report.chart[:data][0][-1]).to eq(1) if other
      end
    end

    it "handles null data in chart column" do
      report = null_data_chart

      expect_any_instance_of(described_class).to receive(:build_numeric_chart_simple).once.and_call_original
      render_report(report)
    end
  end

  context '#build_numeric_chart_grouped_2dim' do
    [true, false].each do |other|
      it "builds 3d numeric charts #{other ? 'with' : 'without'} 'other'" do
        report = numeric_chart_3d(other)

        expect_any_instance_of(described_class).to receive(:build_numeric_chart_grouped_2dim).once.and_call_original
        render_report(report)
        expect(report.chart[:data][0][0]).to eq(6_656)
        expect(report.chart[:data][0][1]).to eq(4_096)
        expect(report.chart[:data][1][1]).to eq(3_072)
        expect(report.chart[:options][:axes][:yaxis][:ticks][0]).to eq('MTC-RHEVM-3.0')
        expect(report.chart[:data][0][-1]).to eq(1_024) if other
      end
    end

    it 'handles namespace-prefixed class names in chart column' do
      report = chart_with_namespace_prefix

      expect_any_instance_of(described_class).to receive(:build_numeric_chart_grouped_2dim).once.and_call_original
      render_report(report)
    end
  end

  context '#build_numeric_chart_simple' do
    let(:report) { numeric_chart_simple }

    it "uses correct formating function for axis with given column format" do
      report.col_formats = [nil, :general_number_precision_0]
      render_report(report)
      expect(report.chart[:options][:axes][:xaxis][:tickOptions][:formatter]).to eq("ManageIQ.charts.formatters.number_with_delimiter.jqplot({\"delimiter\":\",\",\"precision\":0,\"description\":\"Number (1,234)\"})")
    end

    it "uses correct formating function for axis with implicit column format" do
      render_report(report)
      expect(report.chart[:options][:axes][:xaxis][:tickOptions][:formatter]).to eq("ManageIQ.charts.formatters.mbytes_to_human_size.jqplot({\"precision\":1,\"description\":\"Suffixed Megabytes (MB, GB)\"})")
    end
  end
end
